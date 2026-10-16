import AppKit

// One owner for the desktop app; neither MatrizView nor the saver creates capture services.
final class MatrizMedia {
    private let live = MatrizLiveState.shared
    private let artwork = MatrizArtworkService()
    private var audio: AnyObject?
    private var audioArmed = false
    private var paused = false
    private var sleeping = false
    private var inactive = false
    private var audioActive = false
    private var artworkActive = false
    private var settings = MatrizSettings()

    init() {
        live.desktopAvailable = true
        if #available(macOS 14.2, *) {
            let service = MatrizAudioService()
            service.report = { [weak self] status, value in
                guard let self, self.audioActive else { return }
                if self.live.audioStatus != status { self.live.audioStatus = status }
                self.live.audioBusy = false
                if let value { self.live.setAudio(value, at: ProcessInfo.processInfo.systemUptime) }
            }
            audio = service
        }
        artwork.report = { [weak self] status, color, changed in
            guard let self, self.artworkActive else { return }
            if self.live.artworkStatus != status { self.live.artworkStatus = status }
            if changed { self.live.setArtwork(color, at: ProcessInfo.processInfo.systemUptime,
                                             duration: self.settings.artworkTransition) }
        }
        artwork.permissionFinished = { [weak self] in self?.live.artworkBusy = false }
        live.requestAudio = { [weak self] in
            guard let self, self.settings.audioEnabled, self.canRun else { return }
            self.audioArmed = true
            self.live.audioBusy = true
            self.update(retryAudio: true)
        }
        live.requestArtwork = { [weak self] in
            guard let self, self.artworkActive else { return }
            self.live.artworkBusy = true
            self.artwork.connect()
        }
        live.consumersChanged = { [weak self] in self?.update() }
        NotificationCenter.default.addObserver(self, selector: #selector(changed), name: MatrizPreferences.notification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changed), name: .NSProcessInfoPowerStateDidChange, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification,
                     NSWorkspace.accessibilityDisplayOptionsDidChangeNotification] {
            workspace.addObserver(self, selector: #selector(workspaceChanged(_:)), name: name, object: nil)
        }
        update()
    }
    private var canRun: Bool {
        !paused && !sleeping && !inactive && live.hasConsumers && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    func setPaused(_ value: Bool) { paused = value; update() }
    @objc private func changed() { update() }
    @objc private func workspaceChanged(_ notification: Notification) {
        switch notification.name {
        case NSWorkspace.screensDidSleepNotification: sleeping = true
        case NSWorkspace.screensDidWakeNotification: sleeping = false
        case NSWorkspace.sessionDidResignActiveNotification: inactive = true
        case NSWorkspace.sessionDidBecomeActiveNotification: inactive = false
        default: break
        }
        update()
    }
    private func update(retryAudio: Bool = false) {
        guard Thread.isMainThread else { DispatchQueue.main.async { [weak self] in self?.update(retryAudio: retryAudio) }; return }
        settings = MatrizPreferences.shared.settings
        live.configureArtwork(count: settings.artworkColors, intensity: Float(settings.artworkIntensity),
                              duration: settings.artworkTransition, at: ProcessInfo.processInfo.systemUptime)
        if !settings.audioEnabled { audioArmed = false }
        audioActive = canRun && settings.audioEnabled && audioArmed
        artworkActive = canRun && settings.artworkEnabled
        if #available(macOS 14.2, *), let service = audio as? MatrizAudioService {
            service.configure(active: audioActive, settings: settings,
                              lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled, retry: retryAudio)
        }
        if !audioActive {
            live.resetAudio()
            live.audioBusy = false
            live.audioStatus = !settings.audioEnabled ? L("Audio is off")
                : (!canRun ? L("Audio reaction is paused") : L("Activate audio to start listening."))
        }
        artwork.configure(active: artworkActive)
        if !artworkActive {
            live.artworkBusy = false
            live.artworkStatus = settings.artworkEnabled ? L("Album colors are paused") : L("Album colors are off")
            live.setArtwork(nil, at: ProcessInfo.processInfo.systemUptime, duration: settings.artworkTransition)
        }
    }
    func shutdown() {
        audioActive = false; artworkActive = false
        live.requestAudio = nil; live.requestArtwork = nil; live.consumersChanged = nil
        if #available(macOS 14.2, *), let service = audio as? MatrizAudioService { service.shutdown() }
        artwork.shutdown()
        live.resetAudio()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
