import AppKit
import CryptoKit
import MetalKit
import ScreenSaver

@main
enum MatrizCheck {
    static func checkSharedSettings(_ bundle: Bundle) throws {
        let defaults = MatrizSettings(["settingsVersion": 2]).values as NSDictionary
        var keys = Set<String>()
        for file in ["settings", "native-settings"] {
            let data = try Data(contentsOf: bundle.url(forResource: file, withExtension: "json")!)
            let schema = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            for spec in schema["settings"] as! [[String: Any]] {
                let key = spec["key"] as! String
                precondition(keys.insert(key).inserted, "Duplicate setting: \(key)")
                precondition(NSDictionary(dictionary: [key: spec["default"]!]).isEqual(to: [key: defaults[key]!]), "Shared default differs: \(key)")
                if let min = spec["min"] as? Double, let max = spec["max"] as? Double {
                    for (input, expected) in [(min - 10, min), (max + 10, max)] {
                        let value = MatrizSettings(["settingsVersion": 2, key: input]).values[key] as! NSNumber
                        precondition(abs(value.doubleValue - expected) < 1e-12, "Shared bounds differ: \(key)")
                    }
                }
            }
        }
        precondition(keys == Set(defaults.allKeys.compactMap { $0 as? String }).subtracting(["settingsVersion"]), "Shared contract omits native settings")
    }
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
        saved.colorBlur = 0.7
        saved.shadowLight = 0.6
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
        precondition(invalid.speed == 1.50166015625 && invalid.brightness == 1 && invalid.contrast == 0.5)
        precondition(invalid.palette == 8 && invalid.hue == 0 && invalid.spacing == 6 && invalid.size == 1.4)
        precondition(MatrizSettings(["hue": -30]).hue == 0 && MatrizSettings(["hue": 400]).hue == 360)
        precondition(invalid.volumeScale == 0.6 && invalid.quality == 0 && invalid.concavity == 0.78)
        let newSettings = MatrizSettings(["audioEnabled": 1, "audioSensitivity": Double.nan,
            "audioIntensity": 20, "audioResponse": -1, "artworkEnabled": "true", "artworkSource": -3,
            "artworkIntensity": Double.infinity, "artworkTransition": 0])
        precondition(newSettings.audioEnabled && newSettings.audioSensitivity == 0.3258231026785712
                          && newSettings.audioIntensity == 1)
        precondition(newSettings.audioResponse == 0 && newSettings.artworkEnabled)
        precondition(newSettings.artworkIntensity == 1 && newSettings.artworkTransition == 1)
        precondition(MatrizSettings(["settingsVersion": 2, "artworkIntensity": Double.infinity]).artworkIntensity == 1,
                     "El valor nuevo por defecto de la intensidad de portada no se aplica.")
        precondition(MatrizSettings(["palette": 4]).audioEnabled && MatrizSettings(["palette": 4]).artworkEnabled)
        let appearance = MatrizSettings(["waveOpacity": -2, "sparkleOpacity": 9, "waveSizeInfluence": 9,
            "depthConcavityEnabled": 1, "depthConcavity": true, "deformation": Double.nan, "backgroundStyle": 99, "orbSize": Double.infinity, "sparkleShape": -7,
            "paletteRichness": -3, "paletteVariation": 3, "saturation": Double.infinity,
            "vibrance": -4, "colorContrast": 9, "hdrEnabled": "true", "artworkColors": 99,
            "customDeep": [Double.nan, 0, 0], "customLight": [-1, 0.3, 9], "customSoft": [true, false, true]])
        precondition(appearance.waveOpacity == 0 && appearance.sparkleOpacity == 1 && appearance.waveSizeInfluence == 3)
        precondition(MatrizSettings(["shadowLight": -1]).shadowLight == 0 && MatrizSettings(["shadowLight": 2]).shadowLight == 0.8)
        precondition(MatrizSettings(["shadowLight": Double.nan]).shadowLight == 0.32)
        precondition(appearance.depthConcavity == 0 && appearance.deformation == 4)
        precondition(appearance.backgroundStyle == 5 && appearance.orbSize == 1 && appearance.sparkleShape == 0)
        precondition(MatrizSettings(["orbSize": -2, "deformation": 99]).orbSize == 0.2 && MatrizSettings(["deformation": 99]).deformation == 4)
        precondition(appearance.paletteRichness == 0 && appearance.saturation == 1)
        precondition(appearance.colorContrast == 2 && appearance.artworkColors == 4)
        precondition(appearance.customDeep == MatrizSettings().customDeep && appearance.customLight == SIMD3(0, 0.3, 1)
                     && appearance.customSoft == MatrizSettings().customSoft)
        precondition(MemoryLayout<MatrizUniforms>.offset(of: \.audio) == 96 && MemoryLayout<MatrizUniforms>.offset(of: \.color0) == 144)
        precondition(MemoryLayout<MatrizUniforms>.offset(of: \.layout) == 208)
        precondition(MatrizSettings(["colorBlur": -1]).colorBlur == 0 && MatrizSettings(["colorBlur": 2]).colorBlur == 1)
        precondition(MatrizSettings(["colorBlur": Double.nan]).colorBlur == 0.5)
        precondition(MemoryLayout<MatrizUniforms>.offset(of: \.colorBlur) == 240)
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
        precondition(MemoryLayout<MatrizUniforms>.stride == 256, "Layout de uniforms incompatible con Metal.")
    }

    struct BatteryCase {
        var id: String
        var time: Double = 0
        var pixelRatio: Float = 1
        var width: Int = 1440
        var height: Int = 900
        var audio: SIMD4<Float> = .zero
        var artwork: MatrizArtworkColors?
        var configure: (inout MatrizSettings) -> Void = { _ in }
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func runBattery(app: Bundle, output: String) throws {
        let renderer = try MatrizRenderer(bundle: app)
        var textures: [String: MTLTexture] = [:]
        func texture(width: Int, height: Int) -> MTLTexture {
            let key = "\(width)x\(height)"
            if let cached = textures[key] { return cached }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget]
            descriptor.storageMode = .shared
            let created = renderer.device.makeTexture(descriptor: descriptor)!
            textures[key] = created
            return created
        }
        var cases: [BatteryCase] = []
        for style in 0...5 {
            cases.append(BatteryCase(id: "estilo-\(style)-t0", configure: { $0.backgroundStyle = style }))
        }
        for style in 1...5 {
            cases.append(BatteryCase(id: "estilo-\(style)-t2.6", time: 2.6, configure: { $0.backgroundStyle = style }))
        }
        for style in 1...3 {
            cases.append(BatteryCase(id: "estilo-\(style)-onda-desplazada", configure: {
                $0.backgroundStyle = style
                $0.wavePosition = 0.25
            }))
        }
        cases.append(BatteryCase(id: "orbe-desplazado", configure: {
            $0.backgroundStyle = 4
            $0.orbX = 0.3
            $0.orbY = -0.2
        }))
        for (style, orb) in [(4, 0.2), (4, 6.0), (5, 0.2), (5, 6.0)] {
            cases.append(BatteryCase(id: "estilo-\(style)-orbe-\(orb)", configure: {
                $0.backgroundStyle = style
                $0.orbSize = orb
            }))
        }
        for deformation in [0.0, 1.0, 2.0, 4.0] {
            cases.append(BatteryCase(id: "deformacion-\(deformation)", time: 2, configure: { $0.deformation = deformation }))
        }
        cases.append(BatteryCase(id: "deformacion-4-orbe", time: 2, configure: {
            $0.deformation = 4
            $0.backgroundStyle = 4
        }))
        for spacing in [6.0, 12.0, 16.0] {
            cases.append(BatteryCase(id: "espaciado-\(spacing)", configure: { $0.spacing = spacing }))
        }
        for shape in 0...2 {
            cases.append(BatteryCase(id: "geometria-\(shape)-extremo", time: 2, configure: {
                $0.deformation = 4
                $0.spacing = 6
                $0.size = 1.4
                $0.volumeScale = 0.6
                $0.sparkleShape = shape
            }))
        }
        for size in [0.6, 1.4] {
            cases.append(BatteryCase(id: "tamano-\(size)", configure: { $0.size = size }))
        }
        for volume in [0.1, 1.8] {
            cases.append(BatteryCase(id: "volumen-\(volume)", configure: { $0.volumeScale = volume }))
        }
        for shape in 1...2 {
            cases.append(BatteryCase(id: "forma-\(shape)", configure: { $0.sparkleShape = shape }))
        }
        cases.append(BatteryCase(id: "forma-1-sin-concavidad", configure: {
            $0.sparkleShape = 1
            $0.concavity = 0
            $0.depthConcavity = 1
        }))
        for saturation in [0.0, 2.0] {
            cases.append(BatteryCase(id: "saturacion-\(saturation)", configure: { $0.saturation = saturation }))
        }
        for contrast in [0.5, 2.0] {
            cases.append(BatteryCase(id: "contraste-color-\(contrast)", configure: { $0.colorContrast = contrast }))
        }
        cases.append(BatteryCase(id: "sin-destellos", configure: { $0.sparkleOpacity = 0 }))
        cases.append(BatteryCase(id: "sin-destellos-orbe", configure: {
            $0.sparkleOpacity = 0
            $0.backgroundStyle = 4
        }))
        cases.append(BatteryCase(id: "solo-destellos", configure: { $0.waveOpacity = 0 }))
        cases.append(BatteryCase(id: "audio-t0", audio: SIMD4(1, 0, 1, 1)))
        cases.append(BatteryCase(id: "audio-orbe-deformado", time: 1.3, audio: SIMD4(0.3, 0.7, 0.5, 0.6), configure: {
            $0.backgroundStyle = 4
            $0.deformation = 2
        }))
        cases.append(BatteryCase(id: "dpr-1.5", time: 2, pixelRatio: 1.5, configure: { $0.deformation = 4 }))
        cases.append(BatteryCase(id: "dpr-2", time: 2, pixelRatio: 2, configure: { $0.deformation = 4 }))
        cases.append(BatteryCase(id: "pequena-800x600", time: 0.7, pixelRatio: 1.5, width: 800, height: 600, configure: {
            $0.backgroundStyle = 5
            $0.deformation = 4
        }))
        let cover = MatrizArtworkColors(primary: SIMD4(1, 0, 0, 0.8), secondary: SIMD4(0, 0, 1, 1),
                                        tertiary: SIMD4(0, 1, 0, 1), quaternary: SIMD4(1, 1, 0, 1))
        cases.append(BatteryCase(id: "portada", artwork: cover))

        var lines: [String] = []
        do {
            let target = texture(width: 1440, height: 900)
            let command = try renderer.render(texture: target, time: 0, pixelRatio: 1, settings: MatrizSettings())
            command.waitUntilCompleted()
        }
        for item in cases {
            var settings = MatrizSettings()
            item.configure(&settings)
            let start = CFAbsoluteTimeGetCurrent()
            let target = texture(width: item.width, height: item.height)
            let command = try renderer.render(texture: target, time: item.time, pixelRatio: item.pixelRatio,
                                              settings: settings, audio: item.audio, artworkPalette: item.artwork)
            command.waitUntilCompleted()
            if let error = command.error { throw error }
            precondition(command.status == .completed, "Metal no terminó el fotograma de \(item.id).")
            var pixels = [UInt8](repeating: 0, count: target.width * target.height * 4)
            pixels.withUnsafeMutableBytes {
                target.getBytes($0.baseAddress!, bytesPerRow: target.width * 4,
                                from: MTLRegionMake2D(0, 0, target.width, target.height), mipmapLevel: 0)
            }
            let hash = sha256Hex(Data(pixels))
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            lines.append("    { \"id\": \"\(item.id)\", \"sha256\": \"\(hash)\", \"bytes\": \(pixels.count), \"ms\": \(String(format: "%.2f", elapsed)) }")
            print("Bateria: \(item.id) \(hash) \(String(format: "%.1f", elapsed)) ms")
        }
        let json = "{\n  \"cases\": [\n" + lines.joined(separator: ",\n") + "\n  ]\n}\n"
        try Data(json.utf8).write(to: URL(fileURLWithPath: output))
        print("Bateria: \(cases.count) casos escritos en \(output)")
    }

    static func runDump(app: Bundle, folder: String) throws {
        let renderer = try MatrizRenderer(bundle: app)
        func dump(_ id: String, width: Int, height: Int, time: Double, pixelRatio: Float,
                  configure: (inout MatrizSettings) -> Void) throws {
            var settings = MatrizSettings()
            configure(&settings)
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget]
            descriptor.storageMode = .shared
            let target = renderer.device.makeTexture(descriptor: descriptor)!
            let command = try renderer.render(texture: target, time: time, pixelRatio: pixelRatio, settings: settings)
            command.waitUntilCompleted()
            if let error = command.error { throw error }
            precondition(command.status == .completed, "Metal no terminó el volcado de \(id).")
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            pixels.withUnsafeMutableBytes {
                target.getBytes($0.baseAddress!, bytesPerRow: width * 4,
                                from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            }
            try Data(pixels).write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(id).rgba"))
            print("Volcado: \(id) (\(pixels.count) bytes)")
        }
        try dump("estilo-1-t0", width: 1440, height: 900, time: 0, pixelRatio: 1) { $0.backgroundStyle = 1 }
        try dump("estilo-2-t0", width: 1440, height: 900, time: 0, pixelRatio: 1) { $0.backgroundStyle = 2 }
        try dump("dpr-1.5", width: 1440, height: 900, time: 2, pixelRatio: 1.5) { $0.deformation = 4 }
        try dump("pequena-800x600", width: 800, height: 600, time: 0.7, pixelRatio: 1.5) {
            $0.backgroundStyle = 5
            $0.deformation = 4
        }
    }

    static func runDocs(app: Bundle, folder: String) throws {
        let renderer = try MatrizRenderer(bundle: app)
        func shot(_ id: String, width: Int, height: Int, time: Double, pixelRatio: Float,
                  configure: (inout MatrizSettings) -> Void) throws {
            var settings = MatrizSettings()
            configure(&settings)
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget]
            descriptor.storageMode = .shared
            let target = renderer.device.makeTexture(descriptor: descriptor)!
            let command = try renderer.render(texture: target, time: time, pixelRatio: pixelRatio, settings: settings)
            command.waitUntilCompleted()
            if let error = command.error { throw error }
            precondition(command.status == .completed, "Metal no terminó el render de \(id).")
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            pixels.withUnsafeMutableBytes {
                target.getBytes($0.baseAddress!, bytesPerRow: width * 4,
                                from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            }
            let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
            pixels.withUnsafeBytes { image.bitmapData!.update(from: $0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: pixels.count) }
            try image.representation(using: .png, properties: [:])!
                .write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(id).png"))
            print("Docs: \(id) (\(width)x\(height))")
        }
        try shot("banner-base", width: 2560, height: 640, time: 9, pixelRatio: 1) {
            $0.backgroundStyle = 1
            $0.palette = 5
            $0.size = 1.4
        }
        try shot("icono-fondo-a", width: 1024, height: 1024, time: 9, pixelRatio: 1) {
            $0.backgroundStyle = 1
            $0.palette = 5
            $0.size = 1.4
        }
        try shot("icono-fondo-b", width: 1024, height: 1024, time: 2.6, pixelRatio: 1) {
            $0.backgroundStyle = 1
            $0.palette = 5
            $0.size = 1.4
            $0.wavePosition = 0.25
        }
        try shot("icono-fondo-liso", width: 1024, height: 1024, time: 2.6, pixelRatio: 1) {
            $0.backgroundStyle = 1
            $0.palette = 5
            $0.sparkleOpacity = 0
            $0.wavePosition = 0.25
        }
        for style in 0...5 {
            try shot("galeria-\(style)", width: 1280, height: 800, time: 9, pixelRatio: 1) {
                $0.backgroundStyle = style
                $0.palette = 5
            }
        }
    }

    static func main() throws {
        if CommandLine.arguments[1] == "--contract-only" {
            try checkSharedSettings(Bundle(path: CommandLine.arguments[2])!)
            checkSettingsAndClock()
            print("Shared settings and native validation passed")
            return
        }
        if CommandLine.arguments[1] == "--preferences-child" {
            let preferences = MatrizPreferences(domain: CommandLine.arguments[2])
            precondition(preferences.settings.speed == 1.6 && preferences.settings.palette == 2 && preferences.settings.hue == 123)
            precondition(preferences.settings.audioEnabled && preferences.settings.audioSensitivity == 4
                         && preferences.settings.audioIntensity == 0.42 && preferences.settings.audioResponse == 0.9)
            precondition(preferences.settings.artworkEnabled
                         && preferences.settings.artworkIntensity == 0.6 && preferences.settings.artworkTransition == 5)
            precondition(preferences.settings.depthConcavity == 0.7 && preferences.settings.colorBlur == 0.7
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
        if CommandLine.arguments[1] == "--battery" {
            let app = Bundle(path: CommandLine.arguments[2])!
            try runBattery(app: app, output: CommandLine.arguments[3])
            return
        }
        if CommandLine.arguments[1] == "--dump" {
            let app = Bundle(path: CommandLine.arguments[2])!
            try runDump(app: app, folder: CommandLine.arguments[3])
            return
        }
        if CommandLine.arguments[1] == "--docs" {
            let app = Bundle(path: CommandLine.arguments[2])!
            try runDocs(app: app, folder: CommandLine.arguments[3])
            return
        }
        try MatrizAgentCheck.run()
        MatrizMediaCheck.run()
        checkSettingsAndClock()
        try checkPreferences()
        let app = Bundle(path: CommandLine.arguments[1])!
        try checkSharedSettings(app)
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
        var fullStyle = MatrizSettings()
        fullStyle.backgroundStyle = 0
        let full = try frame(0, settings: fullStyle)
        for (x, y) in [(0, 0), (1439, 0), (0, 899), (1439, 899), (720, 450)] {
            let i = (y * 1440 + x) * 4
            precondition(full[i + 3] == 255 && full[i + 2] > 0, "Hay un hueco fuera de la superficie.")
        }
        // El color vuelve a seguir el relieve, con ruido suavizable.
        var colorField = MatrizSettings()
        colorField.backgroundStyle = 0; colorField.sparkleOpacity = 0
        colorField.contrast = 0.5
        let lowRelief = try frame(2, settings: colorField)
        colorField.contrast = 1.5
        let highRelief = try frame(2, settings: colorField)
        var changedTones = 0
        for i in stride(from: 0, to: lowRelief.count, by: 4 * 53) {
            let a = SIMD3<Float>(Float(lowRelief[i]), Float(lowRelief[i+1]), Float(lowRelief[i+2]))
            let b = SIMD3<Float>(Float(highRelief[i]), Float(highRelief[i+1]), Float(highRelief[i+2]))
            let peakA = max(a.x, max(a.y, a.z)), peakB = max(b.x, max(b.y, b.z))
            if min(peakA, peakB) > 30 {
                if simd_length(a / peakA - b / peakB) > 0.055 { changedTones += 1 }
            }
        }
        precondition(changedTones > 1000, "El color no sigue la profundidad de las ondas.")
        colorField.contrast = 1
        colorField.colorBlur = 0
        let crispColors = try frame(2, settings: colorField)
        colorField.colorBlur = 1
        let blurredColors = try frame(2, settings: colorField)
        func colorVariation(_ pixels: [UInt8]) -> Float {
            var difference: Float = 0
            for y in stride(from: 0, to: 900, by: 16) {
                for x in stride(from: 0, to: 1432, by: 8) {
                    let i = (y * 1440 + x) * 4, j = i + 8 * 4
                    let a = SIMD3<Float>(Float(pixels[i]), Float(pixels[i+1]), Float(pixels[i+2]))
                    let b = SIMD3<Float>(Float(pixels[j]), Float(pixels[j+1]), Float(pixels[j+2]))
                    difference += simd_length(a / max(1, max(a.x, max(a.y,a.z))) - b / max(1, max(b.x, max(b.y,b.z))))
                }
            }
            return difference
        }
        precondition(colorVariation(blurredColors) < colorVariation(crispColors) * 0.9,
                     "El control de blur no suaviza las transiciones del color.")
        colorField.contrast = 1
        colorField.shadowLight = 0
        let deepShadows = try frame(2, settings: colorField)
        colorField.shadowLight = 0.8
        let liftedShadows = try frame(2, settings: colorField)
        precondition(zip(deepShadows, liftedShadows).reduce(0) { $0 + Int($1.1) - Int($1.0) } > 100000,
                     "El nuevo control no levanta las sombras.")
        var highlights = MatrizSettings()
        highlights.backgroundStyle = 0; highlights.brightness = 2
        highlights.saturation = 2; highlights.colorContrast = 2
        let white = SIMD4<Float>(1, 1, 1, 1)
        let whiteCover = MatrizArtworkColors(primary: white, secondary: white, tertiary: white, quaternary: white)
        let protected = try frame(2, settings: highlights, audio: SIMD4(repeating: 1), artworkPalette: whiteCover)
        precondition(stride(from: 0, to: protected.count, by: 4).allSatisfy {
            max(protected[$0], max(protected[$0+1], protected[$0+2])) <= 248
        }, "El brillo extremo recorta el color SDR.")
        for style in 1...5 {
            var composition = MatrizSettings()
            composition.backgroundStyle = style; composition.sparkleOpacity = 0
            let idle = try frame(2, settings: composition)
            let bass = try frame(2, settings: composition, audio: SIMD4(1, 0, 0, 1))
            let changedBoundary = stride(from: 0, to: idle.count, by: 4).filter {
                (Int(idle[$0]) + Int(idle[$0+1]) + Int(idle[$0+2]) == 0)
                != (Int(bass[$0]) + Int(bass[$0+1]) + Int(bass[$0+2]) == 0)
            }.count
            precondition(changedBoundary > 1000, "La música no cambia el contorno de la composición \(style).")
            if style >= 4 {
                let treble = try frame(2, settings: composition, audio: SIMD4(0, 0, 1, 1))
                precondition(treble != idle && treble != bass, "Los agudos no dan al orbe una respuesta independiente.")
            }
        }
        print("Shader: color ligado al relieve y ruido suavizable, sombras ajustables, altas luces protegidas y cinco contornos reactivos correctos.")
        let adjustments: [(String, WritableKeyPath<MatrizSettings, Double>, Double)] = [
            ("brillo", \.brightness, 0.4), ("contraste", \.contrast, 0.5),
            ("densidad", \.spacing, 16), ("tamaño", \.size, 1.4),
            ("volúmenes", \.volumeScale, 1.8), ("concavidad", \.concavity, 0), ("matiz", \.hue, 120),
            ("opacidad de onda", \.waveOpacity, 0), ("opacidad de destellos", \.sparkleOpacity, 0),
            ("tamaño por onda", \.waveSizeInfluence, 3), ("desplazamiento", \.deformation, 1),
            ("posición de la onda", \.wavePosition, 0.25),
            ("cantidad de colores", \.paletteRichness, 0), ("blur de color", \.colorBlur, 1),
            ("saturación", \.saturation, 0), ("contraste de color", \.colorContrast, 2)
        ]
        for (name, key, value) in adjustments {
            var settings = MatrizSettings()
            settings[keyPath: key] = value
            let adjusted = try frame(0, settings: settings)
            let difference = zip(first, adjusted).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            precondition(difference > first.count / 10, "El ajuste \(name) no cambia la imagen.")
        }

        for palette in [0, 2, 3, 4, 6, 7, 8] {
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
            if style > 0 { precondition(pixels != styles[0], "Un estilo no altera la composición.") }
        }
        precondition(luminance(styles[1],720,80) == 0 && luminance(styles[1],720,820) > 3, "La onda inferior está invertida.")
        precondition(luminance(styles[2],720,820) == 0 && luminance(styles[2],720,80) > 3, "La onda superior está invertida.")
        precondition(luminance(styles[3],720,80) == 0 && luminance(styles[3],720,820) == 0
                     && luminance(styles[3],720,450) > 3, "La franja no ocupa la zona central.")
        precondition(luminance(styles[4],720,450) > 3 && luminance(styles[4],20,20) == 0, "El orbe no está centrado.")
        precondition(luminance(styles[5],720,450) == 0 && luminance(styles[5],20,20) > 3, "El orbe inverso no deja hueco central.")
        var maskOnly = MatrizSettings()
        maskOnly.backgroundStyle = 0
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
        for style in 1...3 {
            var shifted = MatrizSettings()
            shifted.backgroundStyle = style
            shifted.wavePosition = 0.25
            let shiftedFrame = try frame(0, settings: shifted)
            precondition(shiftedFrame != styles[style], "La posición no desplaza la onda del estilo \(style).")
        }
        var movedOrb = MatrizSettings()
        movedOrb.backgroundStyle = 4
        movedOrb.orbX = 0.3
        let movedFrame = try frame(0, settings: movedOrb)
        precondition(movedFrame != styles[4], "La posición horizontal del orbe no mueve la imagen.")
        movedOrb.orbX = 0
        movedOrb.orbY = -0.3
        let movedFrameY = try frame(0, settings: movedOrb)
        precondition(movedFrameY != styles[4] && movedFrameY != movedFrame, "La posición vertical del orbe no mueve la imagen.")
        var largeOrb = MatrizSettings()
        largeOrb.backgroundStyle = 4; largeOrb.orbSize = 6
        let largeFilled = try frame(0, settings: largeOrb)
        precondition(zip(styles[0],largeFilled).allSatisfy { abs(Int($0.0)-Int($0.1)) <= 1 }, "El orbe no puede superar toda la pantalla.")
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
            extreme.contrast = 1.5
            let loudA = try frame(2, settings: extreme, audio: SIMD4(repeating: 1))
            let loudB = try frame(2 + 1.0/240, settings: extreme, audio: SIMD4(repeating: 1))
            precondition(zip(loudA,loudB).allSatisfy { abs(Int($0.0)-Int($0.1)) <= 28 },
                         "El arrastre musical extremo recorta figuras o provoca saltos.")
            extreme.contrast = 1
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
