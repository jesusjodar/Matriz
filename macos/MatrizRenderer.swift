import AppKit
import MetalKit

struct MatrizUniforms {
    var resolution: SIMD2<Float> = .zero
    var pixelRatio: Float = 1
    var brightness: Float
    var phase: SIMD4<Float> = .zero
    var waveX = SIMD4<Float>.zero
    var waveY = SIMD4<Float>.zero
    var contrast: Float
    var spacing: Float
    var size: Float
    var volumeScale: Float
    var concavity: Float
    var audio: SIMD4<Float> = .zero
    var surface: SIMD4<Float>
    var style: SIMD2<Float>
    var grade: SIMD2<Float>
    var color0: SIMD4<Float>
    var color1: SIMD4<Float>
    var color2: SIMD4<Float>
    var color3: SIMD4<Float>
    var layout: SIMD4<Float>
    var orb: SIMD4<Float> = .zero

    init(width: Int = 1, height: Int = 1, pixelRatio: Float = 1, time: Double = 0,
         settings: MatrizSettings, audio: SIMD4<Float> = .zero, artworkPalette: MatrizArtworkColors? = nil) {
        brightness = Float(settings.brightness)
        contrast = Float(settings.contrast)
        spacing = Float(settings.spacing)
        size = Float(settings.size)
        volumeScale = Float(settings.volumeScale)
        concavity = Float(settings.concavity)
        surface = SIMD4(Float(settings.waveOpacity), Float(settings.sparkleOpacity), Float(settings.waveSizeInfluence),
                        Float(settings.depthConcavity))
        style = SIMD2(Float(settings.deformation), Float(settings.paletteRichness))
        grade = SIMD2(Float(settings.saturation), Float(settings.colorContrast))
        layout = SIMD4(Float(settings.backgroundStyle), Float(settings.orbSize), Float(settings.sparkleShape), Float(settings.wavePosition))
        orb = SIMD4(Float(settings.orbX), Float(settings.orbY), 0, 0)
        let palette = MatrizColor.manualPalette(settings)
        color0 = palette.primary; color1 = palette.secondary
        color2 = palette.tertiary; color3 = palette.quaternary
        setFrame(width: width, height: height, pixelRatio: pixelRatio, time: time, audio: audio)
        replacePalette(artworkPalette)
    }
    mutating func setFrame(width: Int, height: Int, pixelRatio: Float, time: Double, audio: SIMD4<Float>) {
        resolution = SIMD2(Float(width), Float(height)); self.pixelRatio = pixelRatio
        phase = SIMD4(MatrizClock.phase(time, rate: 0.5175), MatrizClock.phase(time, rate: 0.4095),
                      MatrizClock.phase(time, rate: 0.3285), MatrizClock.phase(time, rate: 0.025))
        let bend = SIMD2(sin(phase.w), cos(phase.w)) * 0.65
        let k0 = SIMD2<Float>(5.8, 4.0) + bend
        let k1 = SIMD2<Float>(-4.3, 7.2) + SIMD2(-bend.y, bend.x)
        let k2 = SIMD2<Float>(8.2, -3.6) - bend
        waveX = SIMD4(k0.x, k1.x, k2.x, 0) * pixelRatio / (Float(width) * volumeScale)
        waveY = SIMD4(k0.y, k1.y, k2.y, 0) * pixelRatio / (Float(height) * volumeScale)
        phase = SIMD4(-phase.x + 0.8 - (k0.x + k0.y) * 0.5 / volumeScale,
                       phase.y - 1.2 - (k1.x + k1.y) * 0.5 / volumeScale,
                      -phase.z + 2.4 - (k2.x + k2.y) * 0.5 / volumeScale, 0)
        self.audio = audio
    }
    mutating func replacePalette(_ artwork: MatrizArtworkColors?) {
        guard let artwork else { return }
        func replace(_ base: SIMD4<Float>, _ cover: SIMD4<Float>) -> SIMD4<Float> {
            let amount = min(1, max(0, cover.w))
            let color = base + (cover - base) * amount
            return SIMD4(color.x, color.y, color.z, 1)
        }
        color0 = replace(color0, artwork.primary); color1 = replace(color1, artwork.secondary)
        color2 = replace(color2, artwork.tertiary); color3 = replace(color3, artwork.quaternary)
    }
}

final class MatrizRenderer: NSObject, MTKViewDelegate {
    private static var cache: [URL: MatrizRenderer] = [:]
    static func shared(bundle: Bundle) throws -> MatrizRenderer {
        let key = bundle.bundleURL
        if let renderer = cache[key] { return renderer }
        let renderer = try MatrizRenderer(bundle: bundle)
        cache[key] = renderer
        return renderer
    }
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let framePass = MTLRenderPassDescriptor()
    private var template = MatrizUniforms(settings: MatrizPreferences.shared.settings)

    init(bundle: Bundle) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw NSError(domain: "Matriz", code: 1, userInfo: [NSLocalizedDescriptionKey: L("Metal is not available on this Mac.")])
        }
        let library: MTLLibrary
        if let url = bundle.url(forResource: "Matriz", withExtension: "metallib"),
           let loaded = try? device.makeLibrary(URL: url) {
            library = loaded
        } else if let url = bundle.url(forResource: "Matriz", withExtension: "metal") {
            library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        } else {
            throw NSError(domain: "Matriz", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se encuentra el shader Matriz.metal."])
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "matrizVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "matrizFragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        self.device = device; self.queue = queue
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: MatrizPreferences.notification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func settingsChanged() { template = MatrizUniforms(settings: MatrizPreferences.shared.settings) }

    private func submit(texture: MTLTexture, uniforms: MatrizUniforms, drawable: CAMetalDrawable? = nil) throws -> MTLCommandBuffer {
        guard texture.pixelFormat == .rgba8Unorm, let command = queue.makeCommandBuffer() else {
            throw NSError(domain: "Matriz", code: 3, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el fotograma SDR."])
        }
        framePass.colorAttachments[0].texture = texture
        framePass.colorAttachments[0].loadAction = .dontCare
        framePass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: framePass) else {
            throw NSError(domain: "Matriz", code: 4, userInfo: [NSLocalizedDescriptionKey: "No se pudo dibujar el fotograma Metal."])
        }
        var uniforms = uniforms
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MatrizUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        if let drawable { command.present(drawable) }
        command.commit()
        return command
    }
    func render(texture: MTLTexture, time: Double, pixelRatio: Float, settings: MatrizSettings = MatrizSettings(),
                audio: SIMD4<Float> = .zero, artworkPalette: MatrizArtworkColors? = nil) throws -> MTLCommandBuffer {
        try submit(texture: texture, uniforms: MatrizUniforms(width: texture.width, height: texture.height,
            pixelRatio: pixelRatio, time: time, settings: settings, audio: audio, artworkPalette: artworkPalette))
    }
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let live = MatrizLiveState.shared
        var uniforms = template
        uniforms.setFrame(width: drawable.texture.width, height: drawable.texture.height,
            pixelRatio: Float(view.drawableSize.width / max(view.bounds.width, 1)), time: MatrizClock.shared.time(),
            audio: live.desktopAvailable ? live.audio(at: now) : .zero)
        if live.desktopAvailable { uniforms.replacePalette(live.artwork(at: now)) }
        do { _ = try submit(texture: drawable.texture, uniforms: uniforms, drawable: drawable) }
        catch { view.isPaused = true; NSLog("Matriz: %@", error.localizedDescription) }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

final class MatrizView: MTKView {
    private let renderer: MatrizRenderer
    private let externallyDriven: Bool
    private var active = true
    private var sleeping = false
    private var sessionInactive = false
    private var renderingActive = false
    private var renderScale: CGFloat = 1.5
    var onTimingChange: ((TimeInterval) -> Void)? { didSet { updateState() } }

    init(frame: NSRect, bundle: Bundle, externallyDriven: Bool = false) throws {
        renderer = try MatrizRenderer.shared(bundle: bundle)
        self.externallyDriven = externallyDriven
        super.init(frame: frame, device: renderer.device)
        colorPixelFormat = .rgba8Unorm
        framebufferOnly = true
        autoResizeDrawable = false
        enableSetNeedsDisplay = false
        delegate = renderer
        _ = MatrizPreferences.shared
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(updateState),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(self, selector: #selector(workspaceChanged(_:)), name: name, object: nil)
        }
        for name in [Notification.Name.NSProcessInfoPowerStateDidChange, MatrizPreferences.notification,
                     NSWindow.didChangeOcclusionStateNotification, NSWindow.didChangeScreenNotification,
                     NSApplication.didChangeScreenParametersNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(updateState), name: name, object: nil)
        }
        updateState()
    }

    required init(coder: NSCoder) { fatalError("MatrizView se crea mediante código.") }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        MatrizClock.shared.setActive(self, false)
        MatrizLiveState.shared.setConsumer(self, active: false)
    }

    override func layout() {
        super.layout()
        updateDrawableSize()
    }

    private func updateDrawableSize() {
        let scale = min(window?.backingScaleFactor ?? 1, renderScale)
        let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        if drawableSize != size {
            drawableSize = size
            if renderingActive && isPaused { draw() }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateState()
    }

    func setActive(_ value: Bool) {
        active = value
        updateState()
    }

    func drawExternalFrame() {
        guard renderingActive, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        draw()
    }

    @objc private func workspaceChanged(_ notification: Notification) {
        switch notification.name {
        case NSWorkspace.screensDidSleepNotification: sleeping = true
        case NSWorkspace.screensDidWakeNotification: sleeping = false
        case NSWorkspace.sessionDidResignActiveNotification: sessionInactive = true
        case NSWorkspace.sessionDidBecomeActiveNotification: sessionInactive = false
        default: break
        }
        updateState()
    }

    @objc private func updateState() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.updateState() }
            return
        }
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let policy = MatrizPreferences.shared.settings.policy(
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled, reducedMotion: reduced)
        preferredFramesPerSecond = policy.fps
        renderScale = policy.scale
        renderingActive = active && !sleeping && !sessionInactive && window?.isVisible == true
        MatrizClock.shared.setReducedMotion(reduced)
        MatrizClock.shared.setActive(self, renderingActive)
        MatrizLiveState.shared.setConsumer(self, active: renderingActive)
        isPaused = externallyDriven || !renderingActive || reduced
        onTimingChange?(1.0 / Double(renderingActive ? policy.fps : 1))
        updateDrawableSize()
        if renderingActive && isPaused { draw() }
    }
}
