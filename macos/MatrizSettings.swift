import AppKit
import ScreenSaver
import SwiftUI

struct MatrizSettings: Equatable {
    var speed = 1.0
    var brightness = 1.0
    var contrast = 1.0
    var palette = 1
    var hue = 0.0
    var spacing = 8.0
    var size = 1.0
    var volumeScale = 1.0
    var quality = 1
    var concavity = 0.78
    var waveOpacity = 1.0
    var sparkleOpacity = 1.0
    var waveSizeInfluence = 1.0
    var depthConcavity = 0.0
    var deformation = 0.45
    var backgroundStyle = 0
    var orbSize = 1.0
    var sparkleShape = 0
    var paletteRichness = 1.0
    var saturation = 1.0
    var colorContrast = 1.0
    var customDeep = SIMD3<Double>(0.018, 0.035, 0.13)
    var customLight = SIMD3<Double>(0.10, 0.24, 0.68)
    var customSoft = SIMD3<Double>(0.24, 0.15, 0.55)
    var customAccent = SIMD3<Double>(0.025, 0.48, 0.63)
    var audioEnabled = false
    var audioSensitivity = 6.0
    var audioIntensity = 0.65
    var audioResponse = 0.45
    var artworkEnabled = false
    var artworkIntensity = 1.0
    var artworkTransition = 3.0
    var artworkColors = 3

    init(_ values: [String: Any] = [:]) {
        func number(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            guard let value = values[key] as? NSNumber,
                  CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return fallback }
            return min(range.upperBound, max(range.lowerBound, value.doubleValue))
        }
        func boolean(_ key: String) -> Bool {
            guard let value = values[key] as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
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
        let currentFormat = (values["settingsVersion"] as? Int ?? 0) >= 2
        depthConcavity = currentFormat ? number("depthConcavity", 0, 0...1)
            : (boolean("depthConcavityEnabled") ? number("depthConcavity", 0.5, 0...1) : 0)
        deformation = number("deformation", 0.45, 0...4)
        backgroundStyle = Int(number("backgroundStyle", 0, 0...5).rounded())
        orbSize = number("orbSize", 1, 0.2...6)
        sparkleShape = Int(number("sparkleShape", 0, 0...2).rounded())
        paletteRichness = number("paletteRichness", 1, 0...1)
        saturation = number("saturation", 1, 0...2)
        colorContrast = number("colorContrast", 1, 0.5...2)
        customDeep = color("customDeep", customDeep)
        customLight = color("customLight", customLight)
        customSoft = color("customSoft", customSoft)
        customAccent = color("customAccent", customAccent)
        audioEnabled = boolean("audioEnabled")
        audioSensitivity = number("audioSensitivity", 6, -12...18)
        audioIntensity = number("audioIntensity", 0.65, 0...1)
        audioResponse = number("audioResponse", 0.45, 0...1)
        artworkEnabled = boolean("artworkEnabled")
        artworkIntensity = currentFormat ? number("artworkIntensity", 1, 0...2) : 1
        artworkTransition = number("artworkTransition", 3, 1...8)
        artworkColors = Int(number("artworkColors", 3, 1...4).rounded())
        speed = number("speed", 1, 0.25...2)
        brightness = number("brightness", 1, 0...2)
        contrast = number("contrast", 1, 0.5...1.5)
        palette = Int(number("palette", 1, 0...8).rounded())
        hue = number("hue", 0, 0...360)
        spacing = number("spacing", 8, 6...16)
        size = number("size", 1, 0.6...1.4)
        volumeScale = number("volumeScale", 1, 0.6...1.8)
        quality = Int(number("quality", 1, 0...2).rounded())
        concavity = number("concavity", 0.78, 0...0.85)
    }

    var values: [String: Any] {
        ["settingsVersion": 2, "speed": speed, "brightness": brightness, "contrast": contrast, "palette": palette, "hue": hue,
         "spacing": spacing, "size": size, "volumeScale": volumeScale, "quality": quality, "concavity": concavity,
         "audioEnabled": audioEnabled, "audioSensitivity": audioSensitivity, "audioIntensity": audioIntensity,
         "audioResponse": audioResponse, "artworkEnabled": artworkEnabled,
         "artworkIntensity": artworkIntensity, "artworkTransition": artworkTransition, "artworkColors": artworkColors,
                      "waveOpacity": waveOpacity, "sparkleOpacity": sparkleOpacity, "waveSizeInfluence": waveSizeInfluence,
                      "depthConcavity": depthConcavity,
                      "deformation": deformation, "backgroundStyle": backgroundStyle, "orbSize": orbSize,
                      "sparkleShape": sparkleShape, "paletteRichness": paletteRichness,
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
