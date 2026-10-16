import ScreenSaver
import SwiftUI

@objc(MatrizSaverView)
final class MatrizSaverView: ScreenSaverView {
    private var surface: MatrizView?
    private var settingsWindow: NSWindow?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        do {
            let surface = try MatrizView(frame: bounds, bundle: Bundle(for: MatrizSaverView.self), externallyDriven: true)
            surface.autoresizingMask = [.width, .height]
            addSubview(surface)
            self.surface = surface
            surface.onTimingChange = { [weak self] interval in self?.animationTimeInterval = interval }
        } catch {
            NSLog("Matriz salvapantallas: %@", error.localizedDescription)
            let label = NSTextField(labelWithString: error.localizedDescription)
            label.frame = bounds.insetBy(dx: 24, dy: 24)
            label.autoresizingMask = [.width, .height]
            addSubview(label)
        }
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 800),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.title = L("Matriz Settings")
            window.backgroundColor = .black
            window.appearance = NSAppearance(named: .darkAqua)
            window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: MatrizSettingsPanel(done: { [weak window] in
                guard let window else { return }
                window.sheetParent?.endSheet(window)
                window.orderOut(nil)
            }).frame(width: 760, height: 800))
            settingsWindow = window
        }
        return settingsWindow
    }

    override func startAnimation() {
        super.startAnimation()
        surface?.setActive(true)
    }

    override func stopAnimation() {
        surface?.setActive(false)
        super.stopAnimation()
    }

    override func animateOneFrame() {
        guard isAnimating else { return }
        surface?.drawExternalFrame()
    }
}
