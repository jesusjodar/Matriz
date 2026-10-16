import AppKit
import ScreenSaver
import SwiftUI

struct MatrizSettings: Equatable {
    var speed = 1.50166015625
    var brightness = 1.0
    var contrast = 1.0
    var palette = 5
    var hue = 0.0
    var spacing = 8.0
    var size = 1.0
    var volumeScale = 0.6
    var quality = 1
    var concavity = 0.78
    var waveOpacity = 1.0
    var sparkleOpacity = 1.0
    var waveSizeInfluence = 1.0
    var depthConcavity = 0.75
    var shadowLight = 0.32
    var deformation = 4.0
    var backgroundStyle = 1
    var wavePosition = 0.0
    var orbX = 0.0
    var orbY = 0.0
    var orbSize = 1.0
    var sparkleShape = 0
    var paletteRichness = 1.0
    var colorBlur = 0.5
    var saturation = 1.0
    var colorContrast = 1.0
    var customDeep = SIMD3<Double>(0.018, 0.035, 0.13)
    var customLight = SIMD3<Double>(0.10, 0.24, 0.68)
    var customSoft = SIMD3<Double>(0.24, 0.15, 0.55)
    var customAccent = SIMD3<Double>(0.025, 0.48, 0.63)
    var agentEnabled = false
    var agentSource = "all"
    var audioEnabled = true
    var audioSensitivity = 0.3258231026785712
    var audioIntensity = 0.6976422991071428
    var audioResponse = 0.09794224330357143
    var artworkEnabled = true
    var artworkIntensity = 1.0
    var artworkTransition = 3.0
    var artworkColors = 4

    init(_ values: [String: Any] = [:]) {
        func number(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            guard let value = values[key] as? NSNumber,
                  CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return fallback }
            return min(range.upperBound, max(range.lowerBound, value.doubleValue))
        }
        func boolean(_ key: String, _ fallback: Bool = false) -> Bool {
            guard let value = values[key] as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return fallback }
            return value.boolValue
        }
        func color(_ key: String, _ fallback: SIMD3<Double>) -> SIMD3<Double> {
            guard let channels = values[key] as? [NSNumber], channels.count == 3,
                  channels.allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite }) else { return fallback }
            return SIMD3(channels.map { min(1, max(0, $0.doubleValue)) })
        }
        waveOpacity = number("waveOpacity", 1, 0...1)
        sparkleOpacity = number("sparkleOpacity", 1, 0...1)
        waveSizeInfluence = number("waveSizeInfluence", 1, 0...3)
        shadowLight = number("shadowLight", 0.32, 0...0.8)
        let currentFormat = (values["settingsVersion"] as? Int ?? 0) >= 2
        depthConcavity = currentFormat ? number("depthConcavity", 0.75, 0...1)
            : (values["depthConcavityEnabled"] == nil ? 0.75 : (boolean("depthConcavityEnabled") ? number("depthConcavity", 0.5, 0...1) : 0))
        deformation = number("deformation", 4, 0...4)
        backgroundStyle = Int(number("backgroundStyle", 1, 0...5).rounded())
        wavePosition = number("wavePosition", 0, -0.35...0.35)
        orbX = number("orbX", 0, -0.5...0.5)
        orbY = number("orbY", 0, -0.5...0.5)
        orbSize = number("orbSize", 1, 0.2...6)
        sparkleShape = Int(number("sparkleShape", 0, 0...2).rounded())
        colorBlur = number("colorBlur", 0.5, 0...1)
        paletteRichness = number("paletteRichness", 1, 0...1)
        saturation = number("saturation", 1, 0...2)
        colorContrast = number("colorContrast", 1, 0.5...2)
        customDeep = color("customDeep", customDeep)
        customLight = color("customLight", customLight)
        customSoft = color("customSoft", customSoft)
        customAccent = color("customAccent", customAccent)
        agentEnabled = boolean("agentEnabled")
        if let source = values["agentSource"] as? String, (["all"] + MatrizAgentBridge.agents).contains(source) { agentSource = source }
        audioEnabled = boolean("audioEnabled", true)
        audioSensitivity = number("audioSensitivity", 0.3258231026785712, -12...18)
        audioIntensity = number("audioIntensity", 0.6976422991071428, 0...1)
        audioResponse = number("audioResponse", 0.09794224330357143, 0...1)
        artworkEnabled = boolean("artworkEnabled", true)
        artworkIntensity = currentFormat ? number("artworkIntensity", 1, 0...2) : 1
        artworkTransition = number("artworkTransition", 3, 1...8)
        artworkColors = Int(number("artworkColors", 4, 1...4).rounded())
        speed = number("speed", 1.50166015625, 0.25...2)
        brightness = number("brightness", 1, 0...2)
        contrast = number("contrast", 1, 0.5...1.5)
        palette = Int(number("palette", 5, 0...8).rounded())
        hue = number("hue", 0, 0...360)
        spacing = number("spacing", 8, 6...16)
        size = number("size", 1, 0.6...1.4)
        volumeScale = number("volumeScale", 0.6, 0.6...1.8)
        quality = Int(number("quality", 1, 0...2).rounded())
        concavity = number("concavity", 0.78, 0...0.85)
    }

    var values: [String: Any] {
        ["settingsVersion": 2, "speed": speed, "brightness": brightness, "contrast": contrast, "palette": palette, "hue": hue,
         "spacing": spacing, "size": size, "volumeScale": volumeScale, "quality": quality, "concavity": concavity,
         "agentEnabled": agentEnabled, "agentSource": agentSource,
         "audioEnabled": audioEnabled, "audioSensitivity": audioSensitivity, "audioIntensity": audioIntensity,
         "audioResponse": audioResponse, "artworkEnabled": artworkEnabled,
         "artworkIntensity": artworkIntensity, "artworkTransition": artworkTransition, "artworkColors": artworkColors,
                      "waveOpacity": waveOpacity, "sparkleOpacity": sparkleOpacity, "waveSizeInfluence": waveSizeInfluence,
                      "depthConcavity": depthConcavity, "shadowLight": shadowLight,
                      "deformation": deformation, "backgroundStyle": backgroundStyle, "wavePosition": wavePosition, "orbX": orbX, "orbY": orbY, "orbSize": orbSize,
                      "sparkleShape": sparkleShape, "paletteRichness": paletteRichness, "colorBlur": colorBlur,
                      "saturation": saturation, "colorContrast": colorContrast,
                      "customDeep": [customDeep.x, customDeep.y, customDeep.z],
                      "customLight": [customLight.x, customLight.y, customLight.z],
                      "customSoft": [customSoft.x, customSoft.y, customSoft.z],
                      "customAccent": [customAccent.x, customAccent.y, customAccent.z]]
    }

    func policy(lowPower: Bool, reducedMotion: Bool) -> (fps: Int, scale: CGFloat) {
        let level = lowPower ? 0 : quality
        return (reducedMotion ? 1 : (level == 0 ? 30 : 60), [1, 1.5, 2][level])
    }
}

// Un reloj por proceso conserva la fase al reemplazar ventanas y sincroniza sus pantallas.
final class MatrizClock {
    static let shared = MatrizClock()
    private var seconds = 0.0
    private var anchor: Double
    private var speed = 1.0
    private var audioRate = 1.0
    private var activeViews: Set<ObjectIdentifier> = []
    private var reducedMotion = false

    init(now: Double = ProcessInfo.processInfo.systemUptime) { anchor = now }

    func time(at now: Double = ProcessInfo.processInfo.systemUptime) -> Double {
        if !activeViews.isEmpty && !reducedMotion { seconds += max(0, now - anchor) * speed * audioRate }
        anchor = now
        return seconds
    }

    func setSpeed(_ value: Double, at now: Double = ProcessInfo.processInfo.systemUptime) {
        _ = time(at: now)
        speed = value
    }

    func setAudioRate(_ value: Double, at now: Double = ProcessInfo.processInfo.systemUptime) {
        _ = time(at: now)
        audioRate = value
    }

    func setActive(_ view: AnyObject, _ active: Bool, at now: Double = ProcessInfo.processInfo.systemUptime) {
        _ = time(at: now)
        if active { activeViews.insert(ObjectIdentifier(view)) }
        else { activeViews.remove(ObjectIdentifier(view)) }
    }

    func setReducedMotion(_ value: Bool, at now: Double = ProcessInfo.processInfo.systemUptime) {
        _ = time(at: now)
        reducedMotion = value
    }

    static func phase(_ seconds: Double, rate: Double) -> Float {
        Float((seconds * rate).truncatingRemainder(dividingBy: .pi * 2))
    }
}

final class MatrizPreferences: ObservableObject {
    static let domain = "com.matriz.screensaver"
    static let notification = Notification.Name("com.matriz.settings.changed")
    static let shared = MatrizPreferences()
    @Published private(set) var settings: MatrizSettings
    private let defaults: ScreenSaverDefaults
    private let domain: String

    // ScreenSaverDefaults comparte el dominio del módulo entre la app y el host del salvapantallas.
    init(domain: String = MatrizPreferences.domain, observe: Bool = true) {
        self.domain = domain
        defaults = ScreenSaverDefaults(forModuleWithName: domain)!
        defaults.synchronize()
        settings = MatrizSettings(defaults.dictionary(forKey: "settings") ?? [:])
        if let saved = defaults.dictionary(forKey: "settings"), (saved["settingsVersion"] as? Int ?? 0) < 2 {
            defaults.set(settings.values, forKey: "settings")
            defaults.synchronize()
        }
        MatrizClock.shared.setSpeed(settings.speed)
        if observe {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(reload),
                name: Self.notification, object: domain, suspensionBehavior: .deliverImmediately)
        }
    }

    deinit { DistributedNotificationCenter.default().removeObserver(self) }

    func update(_ value: MatrizSettings) {
        let clean = MatrizSettings(value.values)
        defaults.set(clean.values, forKey: "settings")
        defaults.synchronize()
        apply(clean)
        DistributedNotificationCenter.default().postNotificationName(Self.notification, object: domain,
            userInfo: nil, deliverImmediately: true)
    }

    @objc func reload() {
        defaults.synchronize()
        apply(MatrizSettings(defaults.dictionary(forKey: "settings") ?? [:]))
    }

    private func apply(_ value: MatrizSettings) {
        guard settings != value else { return }
        MatrizClock.shared.setSpeed(value.speed)
        settings = value
        NotificationCenter.default.post(name: Self.notification, object: self)
    }
}
