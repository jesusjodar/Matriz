import AppKit
import SwiftUI

// This inert state is shared with the saver; only MatrizApp installs services and actions.
final class MatrizLiveState: ObservableObject {
    static let shared = MatrizLiveState()
    @Published private(set) var agent: MatrizAgentEvent?
    private var agentColor = MatrizColorTransition()
    @Published var desktopAvailable = false
    @Published var audioStatus = L("Audio is off")
    @Published var artworkStatus = L("Album colors are off")
    @Published var audioBusy = false
    @Published var artworkBusy = false
    var requestAudio: (() -> Void)?
    var requestArtwork: (() -> Void)?
    var consumersChanged: (() -> Void)?
    private var consumers: Set<ObjectIdentifier> = []
    var hasConsumers: Bool { !consumers.isEmpty }
    private var previousAudio = SIMD4<Float>.zero
    private var nextAudio = SIMD4<Float>.zero
    private var audioTime = -Double.infinity
    private var colors = [MatrizColorTransition](repeating: MatrizColorTransition(), count: 4)
    private var palette: [SIMD3<Float>]?
    private var colorCount = 3
    private var tintIntensity: Float = 1

    func configureArtwork(count: Int, intensity: Float, duration: Double, at now: Double) {
        tintIntensity = intensity
        let count = min(4, max(1, count))
        if colorCount != count {
            colorCount = count
            setArtwork(palette, at: now, duration: duration)
        }
    }
    func setArtwork(_ palette: [SIMD3<Float>]?, at now: Double, duration: Double) {
        self.palette = palette
        for index in colors.indices {
            let color = palette.flatMap { $0.isEmpty ? nil : $0[index % min(colorCount, $0.count)] }
            colors[index].set(color, at: now, duration: duration)
        }
    }
    func artwork(at now: Double) -> MatrizArtworkColors {
        MatrizArtworkColors(primary: colors[0].displayValue(at: now, colorIntensity: tintIntensity),
                            secondary: colors[1].displayValue(at: now, colorIntensity: tintIntensity),
                            tertiary: colors[2].displayValue(at: now, colorIntensity: tintIntensity),
                            quaternary: colors[3].displayValue(at: now, colorIntensity: tintIntensity))
    }

    func setAgent(_ event: MatrizAgentEvent?, at now: Double = ProcessInfo.processInfo.systemUptime) {
        guard event != agent else { return }
        if event?.state != agent?.state {
            let color = event.map { event -> SIMD3<Float> in
                let c = event.state.color
                return SIMD3(MatrizColor.linear(c.x), MatrizColor.linear(c.y), MatrizColor.linear(c.z))
            }
            agentColor.set(color, at: now, duration: 0.6)
        }
        agent = event
    }
    func agentPalette(at now: Double) -> MatrizArtworkColors {
        let color = agentColor.displayValue(at: now, colorIntensity: 1)
        return MatrizArtworkColors(primary: color, secondary: color, tertiary: color, quaternary: color)
    }

    static var audioSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }
    func setConsumer(_ consumer: AnyObject, active: Bool) {
        let before = hasConsumers
        if active { consumers.insert(ObjectIdentifier(consumer)) }
        else { consumers.remove(ObjectIdentifier(consumer)) }
        if hasConsumers != before { consumersChanged?() }
    }
    func audio(at now: Double) -> SIMD4<Float> {
        let t = Float(min(1, max(0, (now - audioTime) / (1 / 30))))
        let value = previousAudio + (nextAudio - previousAudio) * t
        return value * Float(exp(-max(0, now - audioTime - 0.2) / 0.65))
    }
    func setAudio(_ value: SIMD4<Float>, at now: Double) {
        previousAudio = audio(at: now)
        nextAudio = value
        audioTime = now
        MatrizClock.shared.setAudioRate(1 + Double(value.y) * 0.35, at: now)
    }
    func resetAudio() {
        previousAudio = .zero
        nextAudio = .zero
        MatrizClock.shared.setAudioRate(1)
    }
}

// Only control/worker queues use this lock; the real-time audio callback never does.
final class MatrizPublicationGate {
    private let lock = NSLock()
    private var value = 0
    func invalidate() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
    func accepts(_ token: Int) -> Bool { lock.lock(); defer { lock.unlock() }; return token == value }
}
