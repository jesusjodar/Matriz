import AppKit
import SwiftUI

final class WallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@main
final class MatrizApp: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var media: MatrizMedia?
    private var paused = false
    private var sleeping = false

    static func main() {
        if MatrizAgentBridge.handleCLI(Array(CommandLine.arguments.dropFirst())) { return }
        let app = NSApplication.shared
        let delegate = MatrizApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Matriz")
        let menu = NSMenu()
        menu.addItem(withTitle: L("Matriz · Animated wallpaper"), action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Pause animation"), action: #selector(togglePause(_:)), keyEquivalent: "p").target = self
        menu.addItem(withTitle: L("Settings…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: L("Screen Saver settings…"), action: #selector(openScreenSaver), keyEquivalent: "").target = self
        menu.addItem(withTitle: L("Using Matriz when locked…"), action: #selector(showHelp), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Quit and remove wallpaper"), action: #selector(quit), keyEquivalent: "q").target = self
        for (title, symbol) in [L("Pause animation"): "pause", L("Settings…"): "slider.horizontal.3",
                                L("Screen Saver settings…"): "display", L("Using Matriz when locked…"): "lock",
                                L("Quit and remove wallpaper"): "power"] {
            menu.item(withTitle: title)?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        statusItem?.menu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildWindows), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            center.addObserver(self, selector: #selector(suspend), name: name, object: nil)
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(self, selector: #selector(resume), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(publishWallpaperSettings), name: MatrizPreferences.notification, object: nil)
        publishWallpaperSettings()
        media = MatrizMedia()
        rebuildWindows()
    }

    @objc private func publishWallpaperSettings() { MatrizWallpaperSettings.publish(MatrizPreferences.shared.settings) }

    @objc private func rebuildWindows() {
        let oldWindows = windows
        var replacements: [NSWindow] = []
        do {
            for screen in NSScreen.screens {
                let window = WallpaperWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
                window.setFrame(screen.frame, display: false)
                window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                window.ignoresMouseEvents = true
                window.isReleasedWhenClosed = false
                window.isOpaque = true
                window.backgroundColor = .black
                window.hasShadow = false
                let surface = try MatrizView(frame: NSRect(origin: .zero, size: screen.frame.size), bundle: .main)
                window.contentView = surface
                surface.setActive(!paused && !sleeping)
                window.orderFrontRegardless()
                replacements.append(window)
            }
            windows = replacements
            oldWindows.forEach { $0.close() }
        } catch {
            replacements.forEach { $0.close() }
            let alert = NSAlert(error: error)
            alert.runModal()
            if windows.isEmpty { NSApp.terminate(nil) }
        }
    }

    private func updateAnimation() {
        windows.forEach { ($0.contentView as? MatrizView)?.setActive(!paused && !sleeping) }
    }

    @objc private func togglePause(_ item: NSMenuItem) {
        paused.toggle()
        media?.setPaused(paused)
        item.title = paused ? L("Resume animation") : L("Pause animation")
        item.image = NSImage(systemSymbolName: paused ? "play" : "pause", accessibilityDescription: nil)
        updateAnimation()
    }

    @objc private func suspend() { sleeping = true; updateAnimation() }
    @objc private func resume() { sleeping = false; updateAnimation() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 800),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("Matriz Settings")
            window.backgroundColor = .black
            window.appearance = NSAppearance(named: .darkAqua)
            window.titlebarAppearsTransparent = true
            window.minSize = NSSize(width: 680, height: 600)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: MatrizSettingsPanel())
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openScreenSaver() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane"))
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = L("Matriz when your Mac is locked")
        alert.informativeText = L("Wallpaper extension: desktop and lock screen.") + "\n\n" + L("Choose Matriz in Wallpaper settings.") + "\n\n" + L("Private API: macOS updates may affect it.")
        alert.addButton(withTitle: L("OK"))
        alert.runModal()
    }

    func applicationWillTerminate(_ notification: Notification) { media?.shutdown() }

    @objc private func quit() { NSApp.terminate(nil) }
}
