// Wallpaper interoperability follows Phosphene's MIT-licensed protocol research.
import AppKit
import ExtensionFoundation
import IOSurface
import MetalKit
import Security

#if !WALLPAPER_CHECK
@main
final class MatrizWallpaper: NSObject, AppExtension {
    required override init() {
        super.init()
        _ = dlopen("/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit", RTLD_NOW)
    }
    var configuration: some AppExtensionConfiguration { MatrizWallpaperConfiguration() }
}
#endif

struct MatrizWallpaperConfiguration: AppExtensionConfiguration {
    func accept(connection: NSXPCConnection) -> Bool {
        guard connection.responds(to: NSSelectorFromString("auditToken")) else { return false }
        var token = connection.auditToken
        let data = withUnsafeBytes(of: &token) { Data($0) }
        var code: SecCode?; var requirement: SecRequirement?
        guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributeAudit: data] as CFDictionary, [], &code) == errSecSuccess,
              let code, SecRequirementCreateWithString("anchor apple" as CFString, [], &requirement) == errSecSuccess,
              let requirement, SecCodeCheckValidity(code, [], requirement) == errSecSuccess else { return false }
        let interface = NSXPCInterface(with: WallpaperExtensionXPCProtocol.self)
        let types = NSMutableSet(array: [NSString.self, NSNumber.self, NSData.self, NSArray.self,
            NSDictionary.self, NSURL.self, NSError.self])
        for name in ["WallpaperIDXPC", "WallpaperCreationRequestXPC", "WallpaperUpdateRequestXPC",
            "WallpaperRemoteContextXPC", "WallpaperSnapshotXPC", "WallpaperContentTypeSetXPC",
            "WallpaperChoiceIDXPC", "WallpaperChoiceIDsXPC", "WallpaperExtensionChoiceRequestXPC",
            "WallpaperChoiceRequestAdditionResultXPC", "WallpaperDebugRequestXPC", "WallpaperDebugResponseXPC",
            "WallpaperMigrationVersionXPC", "WallpaperSettingsViewModelsXPC", "AuditTokenXPC"] {
            if let type = objc_getClass(name) { types.add(type) }
        }
        let classes = types as! Set<AnyHashable>
        for (selector, inputs, output) in [
            ("acquireWithId:request:reply:", 2, true), ("updateWithId:request:reply:", 2, false),
            ("invalidateWithId:reply:", 1, false), ("snapshotWithId:reply:", 1, true),
            ("provideSettingsViewModelsWithContentTypes:reply:", 1, true),
            ("addChoiceRequestWithChoiceRequest:onBehalfOfProcess:reply:", 2, true),
            ("removeChoiceRequestWithChoiceRequest:reply:", 1, false), ("selectedChoicesDidChangeFor:reply:", 1, false),
            ("invokeContextMenuActionWithMenuItemID:groupItemID:reply:", 2, false),
            ("isChoiceDownloadedWith:reply:", 1, false), ("downloadWithChoiceID:reply:", 1, false),
            ("pauseDownloadFor:reply:", 1, false), ("cancelDownloadFor:reply:", 1, false),
            ("resumeDownloadFor:reply:", 1, false), ("removeDownloadFor:reply:", 1, false),
            ("migrateSelectedChoiceFor:reply:", 1, true), ("migrateFrom:to:reply:", 2, false),
            ("skipShuffledContentWithId:reply:", 1, false), ("canSkipShuffledContentWithId:reply:", 1, false),
            ("handleDebugRequestFor:reply:", 1, true), ("handleNotificationWithNamed:reply:", 1, false)
        ] {
            for index in 0..<inputs { interface.setClasses(classes, for: NSSelectorFromString(selector), argumentIndex: index, ofReply: false) }
            if output { interface.setClasses(classes, for: NSSelectorFromString(selector), argumentIndex: 0, ofReply: true) }
        }
        connection.exportedInterface = interface
        connection.exportedObject = MatrizWallpaperHandler()
        connection.remoteObjectInterface = NSXPCInterface(with: WallpaperExtensionProxyXPCProtocol.self)
        connection.resume()
        return true
    }
}

// Private values are inspected by field name; an incompatible layout fails without a raw offset guess.
func wallpaperField(_ name: String, in value: Any, depth: Int = 0) -> Any? {
    guard depth < 7 else { return nil }
    let children = Mirror(reflecting: value).children
    if let field = children.first(where: { $0.label == name }) { return field.value }
    for child in children {
        if let found = wallpaperField(name, in: child.value, depth: depth + 1) { return found }
    }
    return nil
}

func wallpaperBox(_ className: String, field: String, write: (UnsafeMutableRawPointer) -> Void, size: Int) -> AnyObject? {
    guard let type = objc_getClass(className) as? AnyClass,
          let ivar = class_getInstanceVariable(type, field),
          ivar_getOffset(ivar) >= MemoryLayout<UnsafeRawPointer>.size,
          ivar_getOffset(ivar) + size <= class_getInstanceSize(type),
          let instance = class_createInstance(type, 0) else { return nil }
    write(Unmanaged.passUnretained(instance as AnyObject).toOpaque().advanced(by: ivar_getOffset(ivar)))
    return instance as AnyObject
}

final class MatrizWallpaperSurface {
    private static var agentRefresh = -Double.infinity
    let context: CAContext
    let layer = CAMetalLayer()
    private let renderer: MatrizRenderer
    private var timer: Timer?
    private var started = ProcessInfo.processInfo.systemUptime
    private var elapsed = 0.0
    private var settings = MatrizSettings()
    private var settingsStamp: Date?
    private var scale: CGFloat = 1
    private var needsFrame = true
    private(set) var active = false

    init(size: CGSize, scale: CGFloat, bundle: Bundle = .main) throws {
        guard let context = CAContext.remoteContext() as? CAContext, context.contextId != 0 else {
            throw CocoaError(.featureUnsupported)
        }
        self.context = context
        renderer = try MatrizRenderer.shared(bundle: bundle)
        layer.device = renderer.device
        layer.pixelFormat = .rgba8Unorm
        layer.framebufferOnly = true
        layer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        layer.isOpaque = true
        context.layer = layer
        resize(size: size, scale: scale)
        setActive(true)
    }
    func resize(size: CGSize, scale: CGFloat) {
        self.scale = scale.isFinite ? min(2, max(1, scale)) : 1
        needsFrame = true
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.frame = CGRect(origin: .zero, size: size)
        layer.contentsScale = self.scale
        CATransaction.commit()
        reloadSettings()
        draw()
        CATransaction.flush()
    }
    private func reloadSettings() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Matriz-settings.plist")
        let stamp = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard stamp != settingsStamp else { return }
        settingsStamp = stamp
        if let data = try? Data(contentsOf: url), data.count < 65536,
           let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            if active { elapsed += (ProcessInfo.processInfo.systemUptime - started) * settings.speed }
            started = ProcessInfo.processInfo.systemUptime
            settings = MatrizSettings(values)
            needsFrame = true
        }
    }
    func setActive(_ value: Bool) {
        if active != value {
            if active { elapsed += (ProcessInfo.processInfo.systemUptime - started) * settings.speed }
            started = ProcessInfo.processInfo.systemUptime
            active = value
        }
        timer?.invalidate(); timer = nil
        if value {
            draw()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.draw() }
        }
    }
    func draw() {
        reloadSettings()
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let now = ProcessInfo.processInfo.systemUptime
        let live = MatrizLiveState.shared
        if now - Self.agentRefresh >= 0.5 {
            Self.agentRefresh = now
            let event = settings.agentEnabled ? MatrizAgentBridge.latest(source: settings.agentSource) : nil
            if event?.state != live.agent?.state { needsFrame = true }
            live.setAgent(event, at: now - (reduced ? 0.6 : 0))
        }
        if reduced && !needsFrame { return }
        let policy = settings.policy(lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled, reducedMotion: reduced)
        let renderScale = min(scale, policy.scale)
        let size = CGSize(width: max(1, layer.bounds.width * renderScale), height: max(1, layer.bounds.height * renderScale))
        if size != layer.drawableSize { layer.drawableSize = size }
        guard let drawable = layer.nextDrawable() else { return }
        let time = elapsed + (active && !reduced ? (ProcessInfo.processInfo.systemUptime - started) * settings.speed : 0)
        var uniforms = MatrizUniforms(width: drawable.texture.width, height: drawable.texture.height,
            pixelRatio: Float(renderScale), time: time, settings: settings)
        uniforms.replacePalette(live.agentPalette(at: now))
        do { _ = try renderer.submit(texture: drawable.texture, uniforms: uniforms, drawable: drawable); needsFrame = false }
        catch { NSLog("Matriz Wallpaper: %@", error.localizedDescription); setActive(false) }
    }
    deinit { timer?.invalidate() }
}

final class MatrizWallpaperHandler: NSObject, WallpaperExtensionXPCProtocol {
    private let bundle: Bundle
    init(bundle: Bundle = .main) { self.bundle = bundle; super.init() }
    // The host reconnects between desktop and lock; surfaces must outlive those XPC connections.
    private static var surfaces: [String: MatrizWallpaperSurface] = [:]
    private static var cleanup: [String: DispatchWorkItem] = [:]
    private func key(_ id: Any?) -> String? {
        guard let id, let uuid = wallpaperField("uuid", in: id) as? UUID ?? wallpaperField("id", in: id) as? UUID else { return nil }
        return uuid.uuidString
    }
    func acquire(withId id: Any?, request: Any?, reply: @escaping (Any?, Error?) -> Void) {
        DispatchQueue.main.async {
            do {
                guard let id, let request, let key = self.key(id),
                      let size = wallpaperField("size", in: request) as? CGSize,
                      size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
                      size.width <= 16384, size.height <= 16384 else { throw CocoaError(.coderInvalidValue) }
                let scale = wallpaperField("scaleFactor", in: request) as? CGFloat ?? 1
                Self.cleanup.removeValue(forKey: key)?.cancel()
                let surface: MatrizWallpaperSurface
                if let existing = Self.surfaces[key] { surface = existing; surface.resize(size: size, scale: scale); surface.setActive(true) }
                else { surface = try MatrizWallpaperSurface(size: size, scale: scale, bundle: self.bundle); Self.surfaces[key] = surface }
                guard let box = wallpaperBox("WallpaperRemoteContextXPC", field: "box", write: {
                    $0.storeBytes(of: surface.context.contextId, as: UInt32.self)
                }, size: MemoryLayout<UInt32>.size) else { throw CocoaError(.featureUnsupported) }
                reply(box, nil)
            } catch { reply(nil, error) }
        }
    }
    func update(withId id: Any?, request: Any?, reply: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            if let key = self.key(id), let surface = Self.surfaces[key], let request {
                let activity = wallpaperField("activityState", in: request).map { String(describing: $0) } ?? "active"
                surface.setActive(activity != "inactive" && !activity.contains("suspended"))
            }
            reply(nil)
        }
    }
    func invalidate(withId id: Any?, reply: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            if let key = self.key(id) {
                Self.surfaces[key]?.setActive(false)
                Self.cleanup.removeValue(forKey: key)?.cancel()
                let work = DispatchWorkItem { Self.surfaces.removeValue(forKey: key); Self.cleanup.removeValue(forKey: key) }
                Self.cleanup[key] = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: work)
            }
            reply(nil)
        }
    }
    func snapshot(withId id: Any?, reply: @escaping (Any?, Error?) -> Void) {
        DispatchQueue.main.async {
            guard let url = self.bundle.url(forResource: "Matriz-thumbnail", withExtension: "png"),
                  let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let surface = IOSurface(properties: [.width: image.width, .height: image.height, .bytesPerElement: 4, .pixelFormat: 0x42475241]) else {
                reply(nil, CocoaError(.fileReadUnknown)); return
            }
            surface.lock(options: [], seed: nil)
            let context = CGContext(data: surface.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: surface.bytesPerRow, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            surface.unlock(options: [], seed: nil)
            guard context != nil, let box = wallpaperBox("WallpaperSnapshotXPC", field: "rawValue", write: {
                $0.storeBytes(of: Unmanaged.passRetained(surface).toOpaque(), as: UnsafeMutableRawPointer.self)
            }, size: MemoryLayout<UnsafeRawPointer>.size) else { reply(nil, CocoaError(.featureUnsupported)); return }
            reply(box, nil)
        }
    }
    func provideSettingsViewModels(withContentTypes types: Any?, reply: @escaping (Any?, Error?) -> Void) {
        reply(MatrizWallpaperCatalog.models(bundle: bundle), nil)
    }
    func addChoiceRequest(withChoiceRequest request: Any?, onBehalfOfProcess process: Any?, reply: @escaping (Any?, Error?) -> Void) { reply(nil, CocoaError(.featureUnsupported)) }
    func removeChoiceRequest(withChoiceRequest request: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func selectedChoicesDidChange(for id: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func invokeContextMenuAction(withMenuItemID menu: Any?, groupItemID group: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func isChoiceDownloaded(with id: Any?, reply: @escaping (NSNumber?, Error?) -> Void) { reply(NSNumber(value: true), nil) }
    func download(withChoiceID id: Any?, reply: @escaping (Error?) -> Void) -> Any? { reply(nil); return nil }
    func pauseDownload(for id: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func cancelDownload(for id: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func resumeDownload(for id: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func removeDownload(for id: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func migrateSelectedChoice(for id: Any?, reply: @escaping (Any?, Error?) -> Void) { reply(nil, nil) }
    func migrate(from: Any?, to: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func skipShuffledContent(withId id: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func canSkipShuffledContent(withId id: Any?, reply: @escaping (Bool, Error?) -> Void) { reply(false, nil) }
    func handleDebugRequest(for request: Any?, reply: @escaping (Any?, Error?) -> Void) { reply(nil, nil) }
    func handleNotification(withNamed name: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
}
