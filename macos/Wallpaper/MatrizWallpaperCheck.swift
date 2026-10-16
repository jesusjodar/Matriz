import AppKit
import MetalKit

@main
enum MatrizWallpaperCheck {
    static func main() throws {
        _ = NSApplication.shared
        guard dlopen("/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit", RTLD_NOW) != nil else {
            throw CocoaError(.featureUnsupported)
        }
        let bundle = Bundle(path: CommandLine.arguments[1])!
        precondition(MatrizWallpaperCatalog.models(bundle: bundle) != nil, "Wallpaper catalog rejected by the installed macOS runtime")
        let renderer = try MatrizRenderer(bundle: bundle)
        let target = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 640, height: 400, mipmapped: false)
        target.usage = [.renderTarget]; target.storageMode = .shared
        let texture = renderer.device.makeTexture(descriptor: target)!
        let command = try renderer.render(texture: texture, time: 3, pixelRatio: 1)
        command.waitUntilCompleted()
        precondition(command.status == .completed)
        let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 640, pixelsHigh: 400, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 640 * 4, bitsPerPixel: 32)!
        texture.getBytes(image.bitmapData!, bytesPerRow: 640 * 4, from: MTLRegionMake2D(0, 0, 640, 400), mipmapLevel: 0)
        try image.representation(using: .png, properties: [:])!.write(to: bundle.resourceURL!.appendingPathComponent("Matriz-thumbnail.png"))
        let handler = MatrizWallpaperHandler(bundle: bundle)
        struct ID { let id = UUID() }
        struct Destination { let size = CGSize(width: 640, height: 400); let scaleFactor: CGFloat = 1 }
        struct Request { let destination = Destination() }
        let id = ID()
        var acquired = false
        handler.acquire(withId: id, request: Request()) { value, error in
            precondition(error == nil && value != nil, "Remote shader context failed: \(String(describing: error))")
            acquired = true
        }
        let deadline = Date().addingTimeInterval(10)
        while !acquired && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        precondition(acquired)
        var snapshotted = false
        handler.snapshot(withId: id) { value, error in
            precondition(value != nil && error == nil, "IOSurface snapshot failed: \(String(describing: error))")
            snapshotted = true
        }
        while !snapshotted && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        precondition(snapshotted)
        handler.invalidate(withId: id) { _ in }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        print("Wallpaper runtime catalog, Metal thumbnail, remote context and IOSurface snapshot: OK")
    }
}
