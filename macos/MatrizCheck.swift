import AppKit
import MetalKit
import ScreenSaver

@main
enum MatrizCheck {
    static func checkLocalization(_ bundle: Bundle) {
        precondition(bundle.object(forInfoDictionaryKey: "CFBundleName") as? String == "Matriz")
        precondition(bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "Matriz")
        precondition(bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String == "Matriz")
        precondition(bundle.localizations.count == 20, "Faltan idiomas en el bundle.")
        for locale in bundle.localizations {
            let path = bundle.path(forResource: locale, ofType: "lproj")!
            let localized = Bundle(path: path)!
            let title = MatrizI18n.text("About", in: localized)
            precondition(!title.isEmpty && (locale == "en" || title != "About"))
        }
        let spanish = Bundle(path: bundle.path(forResource: "es", ofType: "lproj")!)!
        precondition(MatrizI18n.text("Made with ❤️ in Spain 🇪🇸", in: spanish) == "Hecho con ❤️ desde España 🇪🇸")
        precondition(NSImage(contentsOf: bundle.resourceURL!.appendingPathComponent("Author.jpg")) != nil)
        precondition(FileManager.default.fileExists(atPath: bundle.resourceURL!.appendingPathComponent("Assets.car").path))
    }

    static func checkPreferences() throws {
        let domain = "com.matriz.check.\(UUID().uuidString)"
        let preferences = MatrizPreferences(domain: domain, observe: false)
        defer {
            let defaults = ScreenSaverDefaults(forModuleWithName: domain)!
            defaults.removeObject(forKey: "settings")
            defaults.synchronize()
        }
        precondition(preferences.settings == MatrizSettings(), "El dominio de prueba no está vacío.")
        var saved = MatrizSettings()
        saved.speed = 1.6
        saved.palette = 2
        saved.hue = 123
        saved.audioEnabled = true
        saved.audioSensitivity = 4
        saved.audioIntensity = 0.42
        saved.audioResponse = 0.9
        saved.artworkEnabled = true
        saved.artworkIntensity = 0.6
        saved.artworkTransition = 5
        saved.artworkColors = 4
        saved.waveOpacity = 0.4
        saved.sparkleOpacity = 0.6
        saved.waveSizeInfluence = 2.3
        saved.depthConcavity = 0.7
        saved.deformation = 3.2
        saved.backgroundStyle = 4
        saved.orbSize = 2.7
        saved.sparkleShape = 2
        saved.paletteRichness = 0.7
        saved.saturation = 1.2
        saved.colorContrast = 1.4
        saved.customDeep = SIMD3(0.2, 0.1, 0.3)
        precondition(MatrizSettings(saved.values) == saved, "Los controles nuevos no sobreviven al guardado.")
        preferences.update(saved)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        child.arguments = ["--preferences-child", domain]
        let output = Pipe()
        child.standardOutput = output
        try child.run()
        precondition(output.fileHandleForReading.readData(ofLength: 6) == Data("ready\n".utf8),
                     "El segundo proceso no leyó las preferencias persistidas.")
        saved.brightness = 0.73
        preferences.update(saved)
        child.waitUntilExit()
        precondition(child.terminationStatus == 0, "La notificación entre procesos no actualizó los ajustes.")
        preferences.update(MatrizSettings())
        let restored = MatrizPreferences(domain: domain, observe: false)
        precondition(restored.settings == MatrizSettings(), "Restablecer no persistió los valores iniciales.")
    }

    static func checkSettingsAndClock() {
        let invalid = MatrizSettings(["speed": Double.nan, "brightness": Double.infinity, "contrast": -100,
            "palette": 50, "hue": Double.nan, "spacing": 0, "size": 900, "volumeScale": "1.5", "quality": -1, "concavity": true])
        precondition(invalid.speed == 1 && invalid.brightness == 1 && invalid.contrast == 0.5)
        precondition(invalid.palette == 8 && invalid.hue == 0 && invalid.spacing == 6 && invalid.size == 1.4)
        precondition(MatrizSettings(["hue": -30]).hue == 0 && MatrizSettings(["hue": 400]).hue == 360)
        precondition(invalid.volumeScale == 1 && invalid.quality == 0 && invalid.concavity == 0.78)
        let newSettings = MatrizSettings(["audioEnabled": 1, "audioSensitivity": Double.nan,
            "audioIntensity": 20, "audioResponse": -1, "artworkEnabled": "true", "artworkSource": -3,
            "artworkIntensity": Double.infinity, "artworkTransition": 0])
        precondition(!newSettings.audioEnabled && newSettings.audioSensitivity == 6 && newSettings.audioIntensity == 1)
        precondition(newSettings.audioResponse == 0 && !newSettings.artworkEnabled)
        precondition(newSettings.artworkIntensity == 1 && newSettings.artworkTransition == 1)
        precondition(!MatrizSettings(["palette": 4]).audioEnabled && !MatrizSettings(["palette": 4]).artworkEnabled)
        let appearance = MatrizSettings(["waveOpacity": -2, "sparkleOpacity": 9, "waveSizeInfluence": 9,
            "depthConcavityEnabled": 1, "depthConcavity": true, "deformation": Double.nan, "backgroundStyle": 99, "orbSize": Double.infinity, "sparkleShape": -7,
            "paletteRichness": -3, "paletteVariation": 3, "saturation": Double.infinity,
            "vibrance": -4, "colorContrast": 9, "hdrEnabled": "true", "artworkColors": 99,
            "customDeep": [Double.nan, 0, 0], "customLight": [-1, 0.3, 9], "customSoft": [true, false, true]])
        precondition(appearance.waveOpacity == 0 && appearance.sparkleOpacity == 1 && appearance.waveSizeInfluence == 3)
        precondition(appearance.depthConcavity == 0 && appearance.deformation == 0.45)
        precondition(appearance.backgroundStyle == 5 && appearance.orbSize == 1 && appearance.sparkleShape == 0)
        precondition(MatrizSettings(["orbSize": -2, "deformation": 99]).orbSize == 0.2 && MatrizSettings(["deformation": 99]).deformation == 4)
        precondition(appearance.paletteRichness == 0 && appearance.saturation == 1)
        precondition(appearance.colorContrast == 2 && appearance.artworkColors == 4)
        precondition(appearance.customDeep == MatrizSettings().customDeep && appearance.customLight == SIMD3(0, 0.3, 1)
                     && appearance.customSoft == MatrizSettings().customSoft)
        precondition(MemoryLayout<MatrizUniforms>.offset(of: \.audio) == 96 && MemoryLayout<MatrizUniforms>.offset(of: \.color0) == 144)
        precondition(MemoryLayout<MatrizUniforms>.offset(of: \.layout) == 208)
        let migrated = MatrizSettings(["depthConcavityEnabled": true, "depthConcavity": 0.7, "hdrEnabled": true,
                                       "vibrance": 0.6, "paletteVariation": 1.5, "artworkIntensity": 0.35])
        precondition(migrated.depthConcavity == 0.7 && migrated.artworkIntensity == 1)
        for removed in ["hdrEnabled", "vibrance", "paletteVariation", "artworkSource", "depthConcavityEnabled"] {
            precondition(migrated.values[removed] == nil, "Se sigue guardando un ajuste eliminado.")
        }
        for quality in 0...2 {
            var settings = MatrizSettings()
            settings.quality = quality
            let normal = settings.policy(lowPower: false, reducedMotion: false)
            precondition(normal.fps == (quality == 0 ? 30 : 60) && normal.scale == [1.0, 1.5, 2.0][quality])
            let power = settings.policy(lowPower: true, reducedMotion: false)
            precondition(power.fps == 30 && power.scale == 1)
            precondition(settings.policy(lowPower: true, reducedMotion: true).fps == 1)
        }
        let clock = MatrizClock(now: 0)
        let first = NSObject(), second = NSObject()
        clock.setActive(first, true, at: 0)
        precondition(clock.time(at: 10) == 10)
        clock.setActive(second, true, at: 10)
        clock.setActive(first, false, at: 10)
        precondition(clock.time(at: 12) == 12, "Recrear una ventana reinicia el reloj.")
        clock.setSpeed(2, at: 12)
        precondition(clock.time(at: 12) == 12, "Cambiar velocidad salta de fase.")
        precondition(clock.time(at: 14) == 16)
        clock.setReducedMotion(true, at: 14)
        precondition(clock.time(at: 100) == 16)
        clock.setReducedMotion(false, at: 100)
        clock.setActive(second, false, at: 101)
        precondition(clock.time(at: 1000) == 18, "El reloj sigue con todas las vistas detenidas.")
        clock.setActive(first, true, at: 1000)
        precondition(clock.time(at: 1001) == 20, "Reanudar incluye el tiempo suspendido.")
        let a = MatrizClock.phase(1_000_000_000, rate: 0.5175)
        let b = MatrizClock.phase(1_000_000_000 + 1.0 / 60, rate: 0.5175)
        precondition(abs(Double(b - a) - 0.5175 / 60) < 0.00001, "Se pierde precisión a largo plazo.")
        precondition(MemoryLayout<MatrizUniforms>.stride == 224, "Layout de uniforms incompatible con Metal.")
    }

    static func main() throws {
        if CommandLine.arguments[1] == "--preferences-child" {
            let preferences = MatrizPreferences(domain: CommandLine.arguments[2])
            precondition(preferences.settings.speed == 1.6 && preferences.settings.palette == 2 && preferences.settings.hue == 123)
            precondition(preferences.settings.audioEnabled && preferences.settings.audioSensitivity == 4
                         && preferences.settings.audioIntensity == 0.42 && preferences.settings.audioResponse == 0.9)
            precondition(preferences.settings.artworkEnabled
                         && preferences.settings.artworkIntensity == 0.6 && preferences.settings.artworkTransition == 5)
            precondition(preferences.settings.depthConcavity == 0.7
                         && preferences.settings.waveSizeInfluence == 2.3 && preferences.settings.artworkColors == 4
                         && preferences.settings.customDeep == SIMD3(0.2, 0.1, 0.3))
            precondition(preferences.settings.backgroundStyle == 4 && preferences.settings.orbSize == 2.7
                         && preferences.settings.sparkleShape == 2 && preferences.settings.deformation == 3.2)
            FileHandle.standardOutput.write(Data("ready\n".utf8))
            let deadline = Date().addingTimeInterval(4)
            while preferences.settings.brightness != 0.73 && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            precondition(preferences.settings.brightness == 0.73)
            return
        }
        MatrizMediaCheck.run()
        checkSettingsAndClock()
        try checkPreferences()
        let app = Bundle(path: CommandLine.arguments[1])!
        checkLocalization(app)
        precondition(app.object(forInfoDictionaryKey: "NSAudioCaptureUsageDescription") != nil)
        precondition(app.object(forInfoDictionaryKey: "NSAppleEventsUsageDescription") != nil)
        let renderer = try MatrizRenderer(bundle: app)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1440, height: 900, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared
        let texture = renderer.device.makeTexture(descriptor: descriptor)!
        func frame(_ time: Double, settings: MatrizSettings = MatrizSettings(), audio: SIMD4<Float> = .zero, artworkPalette: MatrizArtworkColors? = nil) throws -> [UInt8] {
            let command = try renderer.render(texture: texture, time: time, pixelRatio: 1, settings: settings, audio: audio, artworkPalette: artworkPalette)
            command.waitUntilCompleted()
            if let error = command.error { throw error }
            precondition(command.status == .completed, "Metal no terminó el fotograma.")
            var pixels = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
            pixels.withUnsafeMutableBytes {
                texture.getBytes($0.baseAddress!, bytesPerRow: texture.width * 4,
                                 from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
            }
            return pixels
        }
        let first = try frame(0)
        let second = try frame(4)
        precondition(first != second, "El shader no anima.")
        var enabledWithoutSignal = MatrizSettings()
        enabledWithoutSignal.audioEnabled = true
        enabledWithoutSignal.artworkEnabled = true
        let neutralEnabled = try frame(0, settings: enabledWithoutSignal)
        precondition(neutralEnabled == first, "Sin señal cambia la imagen original.")
        let reactive = try frame(0, audio: SIMD4(1, 0, 1, 1))
        precondition(reactive != first, "La música no modifica la profundidad ni la luz.")
        var increases = 0, decreases = 0
        for i in stride(from: 0, to: first.count, by: 4) {
            let before = Int(first[i]) + Int(first[i + 1]) + Int(first[i + 2])
            let after = Int(reactive[i]) + Int(reactive[i + 1]) + Int(reactive[i + 2])
            if after > before + 3 { increases += 1 }
            if after < before - 3 { decreases += 1 }
        }
        precondition(increases > 1000 && decreases > 1000, "La música no modifica tanto luces como sombras.")
        let repeated = try frame(0)
        precondition(first == repeated, "El mismo instante no es determinista.")
        var hidden = MatrizSettings()
        hidden.waveOpacity = 0
        hidden.sparkleOpacity = 0
        let black = try frame(0, settings: hidden, audio: SIMD4(repeating: 1))
        precondition(stride(from: 0, to: black.count, by: 4).allSatisfy {
            black[$0] == 0 && black[$0 + 1] == 0 && black[$0 + 2] == 0 && black[$0 + 3] == 255
        }, "Las opacidades cero no ocultan la superficie.")
        var moving = MatrizSettings()
        moving.depthConcavity = 1
        moving.deformation = 1
        let movingA = try frame(2, settings: moving)
        let movingB = try frame(2 + 1.0 / 240, settings: moving)
        precondition(zip(movingA, movingB).allSatisfy { abs(Int($0.0) - Int($0.1)) <= 24 },
                     "La forma o el desplazamiento cambian con saltos.")
        let dynamicShape = try frame(0, settings: moving)
        moving.depthConcavity = 0
        let staticShape = try frame(0, settings: moving)
        precondition(dynamicShape != staticShape, "La concavidad no sigue la profundidad.")
        let coverColors = MatrizArtworkColors(primary: SIMD4(1, 0, 0, 0.8), secondary: SIMD4(0, 0, 1, 1),
                                              tertiary: SIMD4(0, 1, 0, 1), quaternary: SIMD4(1, 1, 0, 1))
        let multicolor = try frame(0, artworkPalette: coverColors)
        let singlePalette = MatrizArtworkColors(primary: coverColors.primary, secondary: coverColors.primary,
                                                tertiary: coverColors.primary, quaternary: coverColors.primary)
        let singleColor = try frame(0, artworkPalette: singlePalette)
        precondition(multicolor != singleColor && multicolor != first, "La portada sigue usando un solo color.")
        var noCover = coverColors
        noCover.primary.w = 0; noCover.secondary.w = 0; noCover.tertiary.w = 0; noCover.quaternary.w = 0
        let neutralCover = try frame(0, artworkPalette: noCover)
        precondition(neutralCover == first, "Intensidad cero no recupera la paleta.")
        for (x, y) in [(0, 0), (1439, 0), (0, 899), (1439, 899), (720, 450)] {
            let i = (y * 1440 + x) * 4
            precondition(first[i + 3] == 255 && first[i + 2] > 0, "Hay un hueco fuera de la superficie.")
        }
        let adjustments: [(String, WritableKeyPath<MatrizSettings, Double>, Double)] = [
            ("brillo", \.brightness, 0.4), ("contraste", \.contrast, 0.5),
            ("densidad", \.spacing, 16), ("tamaño", \.size, 1.4),
            ("volúmenes", \.volumeScale, 1.8), ("concavidad", \.concavity, 0), ("matiz", \.hue, 120),
            ("opacidad de onda", \.waveOpacity, 0), ("opacidad de destellos", \.sparkleOpacity, 0),
            ("tamaño por onda", \.waveSizeInfluence, 3), ("desplazamiento", \.deformation, 1),
            ("cantidad de colores", \.paletteRichness, 0),
            ("saturación", \.saturation, 0), ("contraste de color", \.colorContrast, 2)
        ]
        for (name, key, value) in adjustments {
            var settings = MatrizSettings()
            settings[keyPath: key] = value
            let adjusted = try frame(0, settings: settings)
            let difference = zip(first, adjusted).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            precondition(difference > first.count / 10, "El ajuste \(name) no cambia la imagen.")
        }

        for palette in [0, 2, 3, 4, 5, 6, 7, 8] {
            var settings = MatrizSettings()
            settings.palette = palette
            let adjusted = try frame(0, settings: settings)
            precondition(first != adjusted, "La paleta no cambia la imagen.")
        }
        var hueCycle = MatrizSettings()
        hueCycle.hue = 360
        let cycled = try frame(0, settings: hueCycle)
        precondition(zip(first, cycled).allSatisfy { abs(Int($0.0) - Int($0.1)) <= 1 }, "El matiz no cierra el círculo de color.")
        hueCycle.palette = 7
        hueCycle.hue = 0
        let gray = try frame(0, settings: hueCycle)
        hueCycle.hue = 120
        let rotatedGray = try frame(0, settings: hueCycle)
        precondition(zip(gray, rotatedGray).allSatisfy { abs(Int($0.0) - Int($0.1)) <= 1 }, "El matiz tiñe el gris neutro.")
        var custom = MatrizSettings()
        custom.palette = 8
        custom.customDeep = SIMD3(0.05, 0.01, 0)
        custom.customLight = SIMD3(0.9, 0.1, 0.02)
        custom.customSoft = SIMD3(0.6, 0.02, 0.1)
        custom.customAccent = SIMD3(1, 0.6, 0.05)
        let customFrame = try frame(0, settings: custom)
        precondition(customFrame != first, "La paleta personalizada no llega a Metal.")
        custom.paletteRichness = 0
        let oneTone = try frame(0, settings: custom)
        for i in stride(from: 0, to: oneTone.count, by: 4 * 31) {
            let r = Double(oneTone[i]), g = Double(oneTone[i + 1]), b = Double(oneTone[i + 2])
            precondition(abs(r * 0.1 - g * 0.9) <= 1 && abs(r * 0.02 - b * 0.9) <= 1,
                         "Cantidad de colores cero no simplifica la paleta personalizada a un tono.")
        }
        let pureRed = SIMD4<Float>(1, 0, 0, 1)
        let replacement = MatrizArtworkColors(primary: pureRed, secondary: pureRed, tertiary: pureRed, quaternary: pureRed)
        let replaced = try frame(0, artworkPalette: replacement)
        var otherPalette = MatrizSettings()
        otherPalette.palette = 3; otherPalette.hue = 210
        let replacedOther = try frame(0, settings: otherPalette, artworkPalette: replacement)
        precondition(replaced == replacedOther, "La paleta o el matiz manual contaminan los colores de portada.")
        precondition(stride(from: 0, to: replaced.count, by: 4).allSatisfy { replaced[$0 + 1] <= 1 && replaced[$0 + 2] <= 1 },
                     "La portada roja está siendo teñida por la paleta anterior.")
        var oneColor = MatrizSettings()
        oneColor.paletteRichness = 0
        let singleReplaced = try frame(0, settings: oneColor, artworkPalette: replacement)
        precondition(zip(replaced, singleReplaced).allSatisfy { abs(Int($0.0) - Int($0.1)) <= 1 },
                     "Al reducir la variedad aparecen huecos oscuros en una paleta de un solo tono.")
        var dump = MatrizUniforms(width: 1440, height: 900, pixelRatio: 1, time: 2, settings: MatrizSettings())
        try withUnsafeBytes(of: &dump) { try Data($0).write(to: app.bundleURL.deletingLastPathComponent().appendingPathComponent("benchmark-new.uniforms")) }
        precondition(NSImage(contentsOf: app.resourceURL!.appendingPathComponent("Matriz.icns")) != nil, "El icono no está incluido en la app.")
        func save(_ pixels: [UInt8], to path: String, width: Int = 1440, height: Int = 900) throws {
            let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
            pixels.withUnsafeBytes { image.bitmapData!.update(from: $0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: pixels.count) }
            try image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
        }
        try save(first, to: CommandLine.arguments[2])
        var dense = MatrizSettings()
        dense.spacing = 6
        dense.size = 1.4
        dense.palette = 2
        let denseFrame = try frame(0, settings: dense)
        precondition(denseFrame != first)
        try save(denseFrame, to: URL(fileURLWithPath: CommandLine.arguments[2]).deletingLastPathComponent()
            .appendingPathComponent("Matriz-dense-preview.png").path)
        let folder = app.bundleURL.deletingLastPathComponent()
        var styles: [[UInt8]] = []
        func luminance(_ pixels: [UInt8], _ x: Int, _ y: Int) -> Int {
            let i = (y * 1440 + x) * 4
            return Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
        }
        for style in 0...5 {
            var setting = MatrizSettings()
            setting.backgroundStyle = style
            let pixels = try frame(0, settings: setting)
            styles.append(pixels)
            try save(pixels, to: folder.appendingPathComponent("Matriz-style-\(style).png").path)
            if style > 0 { precondition(pixels != first, "Un estilo no altera la composición.") }
        }
        precondition(luminance(styles[1],720,80) == 0 && luminance(styles[1],720,820) > 3, "La onda inferior está invertida.")
        precondition(luminance(styles[2],720,820) == 0 && luminance(styles[2],720,80) > 3, "La onda superior está invertida.")
        precondition(luminance(styles[3],720,80) == 0 && luminance(styles[3],720,820) == 0
                     && luminance(styles[3],720,450) > 3, "La franja no ocupa la zona central.")
        precondition(luminance(styles[4],720,450) > 3 && luminance(styles[4],20,20) == 0, "El orbe no está centrado.")
        precondition(luminance(styles[5],720,450) == 0 && luminance(styles[5],20,20) > 3, "El orbe inverso no deja hueco central.")
        var maskOnly = MatrizSettings()
        maskOnly.sparkleOpacity = 0
        let fullWave = try frame(0, settings: maskOnly)
        maskOnly.backgroundStyle = 4
        let orbWave = try frame(0, settings: maskOnly)
        maskOnly.backgroundStyle = 5
        let inverseWave = try frame(0, settings: maskOnly)
        var fading = 0
        for i in stride(from: 0, to: fullWave.count, by: 4) {
            for c in 0...2 { precondition(abs(Int(orbWave[i+c]) + Int(inverseWave[i+c]) - Int(fullWave[i+c])) <= 3,
                                         "Las máscaras de orbe no son complementarias.") }
            if fullWave[i+2] > 10 && orbWave[i+2] > 2 && Int(orbWave[i+2]) < Int(fullWave[i+2]) - 2 { fading += 1 }
        }
        precondition(fading > 10000, "El borde del estilo es un recorte duro.")
        var largeOrb = MatrizSettings()
        largeOrb.backgroundStyle = 4; largeOrb.orbSize = 6
        let largeFilled = try frame(0, settings: largeOrb)
        precondition(zip(first,largeFilled).allSatisfy { abs(Int($0.0)-Int($0.1)) <= 1 }, "El orbe no puede superar toda la pantalla.")
        largeOrb.backgroundStyle = 5
        let largeHole = try frame(0, settings: largeOrb)
        precondition(stride(from:0,to:largeHole.count,by:4).allSatisfy { largeHole[$0] == 0 && largeHole[$0+1] == 0 && largeHole[$0+2] == 0 })
        largeOrb.backgroundStyle = 4; largeOrb.orbSize = 0.2
        let smallOrb = try frame(0, settings: largeOrb)
        let litSmall = stride(from:0,to:smallOrb.count,by:4).filter { smallOrb[$0+2] > 2 }.count
        let litNormal = stride(from:0,to:styles[4].count,by:4).filter { styles[4][$0+2] > 2 }.count
        precondition(litNormal > litSmall * 4, "El tamaño del orbe no tiene efecto suficiente.")
        for shape in 1...2 {
            var geometric = MatrizSettings()
            geometric.sparkleShape = shape
            let pixels = try frame(0, settings: geometric)
            precondition(pixels != first, "La geometría no cambia la máscara.")
            geometric.concavity = 0; geometric.depthConcavity = 1
            let noCurve = try frame(0, settings: geometric)
            precondition(pixels == noCurve, "La concavidad deforma círculos o cuadrados.")
        }
        for shape in 0...2 {
            var extreme = MatrizSettings()
            extreme.deformation = 4; extreme.spacing = 6; extreme.size = 1.4
            extreme.volumeScale = 0.6; extreme.sparkleShape = shape
            let a = try frame(2, settings: extreme)
            let b = try frame(2 + 1.0/240, settings: extreme)
            precondition(zip(a,b).allSatisfy { abs(Int($0.0)-Int($0.1)) <= 28 }, "El desplazamiento ampliado recorta figuras o provoca saltos.")
            extreme.deformation = 1
            let smaller = try frame(2, settings: extreme)
            precondition(a != smaller, "El nuevo rango de desplazamiento no cambia el resultado.")
        }
        let sheet = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:960,pixelsHigh:900,bitsPerSample:8,samplesPerPixel:4,
                                     hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:960*4,bitsPerPixel:32)!
        let context = CGContext(data:sheet.bitmapData,width:960,height:900,bitsPerComponent:8,bytesPerRow:960*4,
                                space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        for (index,pixels) in styles.enumerated() {
            let provider = CGDataProvider(data:Data(pixels) as CFData)!
            let image = CGImage(width:1440,height:900,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:1440*4,
                space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
                provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!
            context.draw(image,in:CGRect(x:(index%2)*480,y:(2-index/2)*300,width:480,height:300))
        }
        try sheet.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("Matriz-styles-preview.png"))
        print("Estilos: seis composiciones suaves, orbes escalables, tres geometrías y desplazamiento 400 % correctos.")
        let saver = Bundle(path: CommandLine.arguments[3])!
        checkLocalization(saver)
        precondition(saver.object(forInfoDictionaryKey: "NSAudioCaptureUsageDescription") == nil
                     && saver.object(forInfoDictionaryKey: "NSAppleEventsUsageDescription") == nil)
        try saver.loadAndReturnError()
        precondition(saver.principalClass != nil, "No se puede cargar el salvapantallas.")
        print("Metal: renderizado, ajustes, animación, cobertura y carga del salvapantallas correctos.")
        print("Ajustes: validación, perfiles de energía, reloj y preferencias/notificación entre procesos correctos.")
    }
}
