import AppKit
import CoreAudio
import Carbon
import ImageIO
import simd

enum MatrizMediaCheck {
    static func run() {
        checkBuffer()
        checkDSP()
        checkColor()
        let gate = MatrizPublicationGate()
        let old = gate.invalidate(), current = gate.invalidate()
        precondition(!gate.accepts(old) && gate.accepts(current), "Se acepta una entrega de una sesión anterior.")
        precondition(!MatrizLiveState.shared.desktopAvailable && MatrizLiveState.shared.requestAudio == nil
                     && MatrizLiveState.shared.requestArtwork == nil, "El host compartido activa servicios de escritorio.")
        let track = MatrizPlayer.property("pTrk")
        precondition(track.descriptorType == typeObjectSpecifier)
        precondition(MatrizPlayer.artwork(in: track).descriptorType == typeObjectSpecifier)
        precondition(MatrizArtworkDownload.valid(URL(string: "https://i.scdn.co/image/test")!))
        for address in ["http://example.com/image", "file:///tmp/image", "https://user:password@example.com/image"] {
            precondition(!MatrizArtworkDownload.valid(URL(string: address)!))
        }
        print("Música: buffer SPSC, DSP sintético, color/OKLab, cancelación, caché y URLs correctos; sin capturas ni consultas reales.")
    }
    private static func checkBuffer() {
        let flags = UInt32(kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked)
        let storage = MatrizAudioBufferCreate(2, 32, flags)!
        defer { MatrizAudioBufferDestroy(storage) }
        var input = (0..<2048).flatMap { [Float($0), -Float($0)] }
        var output = [Float](repeating: 0, count: 4096)
        func write() {
            input.withUnsafeMutableBytes { bytes in
                var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2,
                    mDataByteSize: UInt32(bytes.count), mData: bytes.baseAddress))
                MatrizAudioBufferWrite(storage, &list)
            }
        }
        for _ in 0..<20 {
            write()
            let count = output.withUnsafeMutableBufferPointer { MatrizAudioBufferRead(storage, $0.baseAddress!, 2048) }
            precondition(count == 2048 && output == input, "El buffer pierde canales o falla al envolver sus índices.")
        }
        for _ in 0..<9 { write() } // Fill and overflow: the producer must not overwrite unread samples.
        let count = output.withUnsafeMutableBufferPointer { MatrizAudioBufferRead(storage, $0.baseAddress!, 2048) }
        precondition(count == 2048 && output == input)
        precondition(output.withUnsafeMutableBufferPointer { MatrizAudioBufferRead(storage, $0.baseAddress!, 2048) } == 0)
        input[0] = .nan
        write()
        _ = output.withUnsafeMutableBufferPointer { MatrizAudioBufferRead(storage, $0.baseAddress!, 2048) }
        precondition(output[0] == 0, "La captura publica NaN.")
    }
    private static func checkDSP() {
        func signal(_ frequency: Double, amplitude: Float = 0.08, opposite: Bool = false) -> [Float] {
            (0..<2048).flatMap { i -> [Float] in
                let x = amplitude * Float(sin(Double(i) * 2 * .pi * frequency / 48000))
                return [x, opposite ? -x : x]
            }
        }
        func feed(_ analysis: MatrizAudioAnalysis, _ samples: [Float], ticks: Int = 90,
                  offset: Double = 0, sensitivity: Double = 0) -> SIMD4<Float> {
            var value = SIMD4<Float>.zero
            for i in 0..<ticks {
                value = samples.withUnsafeBufferPointer {
                    analysis.process($0, frames: samples.count / 2, at: offset + Double(i) / 30, sensitivity: sensitivity)
                }
                precondition((0..<4).allSatisfy { value[$0].isFinite && (0...1).contains(value[$0]) })
            }
            return value
        }
        for (frequency, band) in [(93.75, 0), (1007.8125, 1), (6000.0, 2)] {
            let samples = signal(frequency)
            let same = feed(MatrizAudioAnalysis(sampleRate: 48000, channels: 2), samples)
            let opposite = feed(MatrizAudioAnalysis(sampleRate: 48000, channels: 2), signal(frequency, opposite: true))
            precondition(same[band] > 0.2 && (0..<3).filter { $0 != band }.allSatisfy { same[$0] < same[band] * 0.02 },
                         "La FFT asigna una senoide a la banda equivocada.")
            precondition(simd_length(same - opposite) < 0.00001, "La contrafase estéreo cancela la reacción.")
        }
        let mixed = zip(signal(93.75), signal(6000, amplitude: 0.012)).map(+)
        let mixBands = feed(MatrizAudioAnalysis(sampleRate: 48000, channels: 2), mixed, ticks: 600)
        precondition(mixBands.x > 0.5 && mixBands.z > 0.4,
                     "El bajo enmascara los agudos de una mezcla sostenida.")
        let silence = [Float](repeating: 0, count: 4096)
        precondition(feed(MatrizAudioAnalysis(sampleRate: 48000, channels: 2), silence) == .zero)
        precondition(feed(MatrizAudioAnalysis(sampleRate: 48000, channels: 2), signal(1000, amplitude: 0.0001)) == .zero)
        let normal = feed(MatrizAudioAnalysis(sampleRate: 48000, channels: 2), signal(1000, amplitude: 0.02))
        let sensitive = feed(MatrizAudioAnalysis(sampleRate: 48000, channels: 2), signal(1000, amplitude: 0.02), sensitivity: 12)
        precondition(sensitive.w > normal.w * 1.5, "La normalización anula la sensibilidad.")
        let quietAnalysis = MatrizAudioAnalysis(sampleRate: 48000, channels: 2)
        let early = feed(quietAnalysis, signal(1000, amplitude: 0.005), ticks: 30)
        let later = feed(quietAnalysis, signal(1000, amplitude: 0.005), ticks: 600, offset: 1)
        precondition(later.w > early.w * 1.5 && later.w < 0.5, "La normalización no adapta música suave de forma acotada.")
        let decay = MatrizAudioAnalysis(sampleRate: 48000, channels: 2)
        let loud = feed(decay, signal(1000))
        let empty: [Float] = []
        let first = empty.withUnsafeBufferPointer { decay.process($0, frames: 0, at: 3.0) }
        precondition(first.w > loud.w * 0.9, "Un bloque ausente provoca un salto.")
        let end = feed(decay, [], ticks: 240, offset: 3.05)
        precondition(end.w < 0.0001, "La señal vieja no decae al faltar callbacks.")
        _ = empty.withUnsafeBufferPointer { decay.process($0, frames: 2048, at: 20) }
        _ = empty.withUnsafeBufferPointer { decay.process($0, frames: -1, at: 21) }
        precondition(decay.value.w.isFinite, "Un tamaño inválido lee fuera del buffer.")
    }
    private static func checkColor() {
        func png(_ rgba: [UInt8], otherRows: [[UInt8]] = []) -> Data {
            let rows = [rgba] + otherRows
            var pixels = (0..<16).flatMap { rows[($0 / 4) % rows.count] }
            return pixels.withUnsafeMutableBytes { bytes in
                let context = CGContext(data: bytes.baseAddress, width: 4, height: 4, bitsPerComponent: 8,
                    bytesPerRow: 16, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
                let data = NSMutableData()
                let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, context.makeImage()!, nil)
                precondition(CGImageDestinationFinalize(destination))
                return data as Data
            }
        }
        let neutralColors: [[UInt8]] = [[0, 0, 0, 255], [255, 255, 255, 255], [128, 128, 128, 255], [0, 0, 0, 0]]
        for rgba in neutralColors.prefix(3) {
            let colors = MatrizColor.extract(png(rgba))!
            precondition(colors.count == 1 && colors.allSatisfy { abs($0.x - $0.y) < 0.001 && abs($0.y - $0.z) < 0.001 },
                         "Una portada neutra debe mantener sus grises sin recuperar la paleta manual.")
        }
        precondition(MatrizColor.extract(png(neutralColors[3])) == nil)
        let grayCover = MatrizColor.extract(png([0, 0, 0, 255], otherRows: [[255, 255, 255, 255], [128, 128, 128, 255]]))!
        precondition(grayCover.count >= 3 && grayCover.allSatisfy { abs($0.x - $0.y) < 0.001 && abs($0.y - $0.z) < 0.001 })
        let pastel = MatrizColor.extract(png([190, 200, 210, 255]))!
        precondition(pastel.count == 1 && pastel[0].z > pastel[0].x)

        let redPalette = MatrizColor.extract(png([255, 0, 0, 255]))!
        precondition(redPalette.count == 1, "Una portada de un solo tono inventa colores extra.")
        let red = redPalette[0]
        precondition(red.x > 0.9 && red.y < 0.01 && red.z < 0.01)
        let multiple = MatrizColor.extract(png([255, 0, 0, 255], otherRows:
            [[0, 255, 0, 255], [0, 0, 255, 255], [255, 255, 0, 255]]))!
        precondition(multiple.count == 4, "La portada multicolor no proporciona cuatro tonos distintos.")
        for i in multiple.indices {
            for j in multiple.indices where j > i {
                precondition(simd_distance(MatrizColor.lab(multiple[i]), MatrizColor.lab(multiple[j])) >= 0.085)
            }
        }
        precondition(MatrizColor.extract(Data([1, 2, 3])) == nil)
        precondition(MatrizColor.extract(Data(count: MatrizColor.maximumBytes + 1)) == nil)
        let blue = SIMD3<Float>(0, 0, 1)
        precondition(simd_length(MatrizColor.rgb(MatrizColor.lab(red)) - red) < 0.00001)
        let vivid = SIMD3<Float>(0.65, 0.55, 0.35)
        let mapped = MatrizColor.lab(MatrizColor.rgb(vivid))
        precondition(abs(atan2(mapped.z, mapped.y) - atan2(vivid.z, vivid.y)) < 0.01,
                     "La compresión de gama cambia el matiz de una portada saturada.")
        var transition = MatrizColorTransition()
        transition.set(red, at: 0, duration: 3)
        precondition(transition.value(at: 0, intensity: 1).w == 0)
        let before = transition.value(at: 1.5, intensity: 1)
        precondition(abs(before.w - 0.5) < 0.00001)
        transition.set(blue, at: 1.5, duration: 3)
        let after = transition.value(at: 1.5, intensity: 1)
        precondition(simd_length(before - after) < 0.00001, "Cambiar de canción salta de color.")
        let end = transition.value(at: 4.5, intensity: 1)
        precondition(end.z > 0.99 && end.x < 0.01 && end.w == 1)
        transition.set(nil, at: 5, duration: 3)
        precondition(transition.value(at: 8, intensity: 1).w == 0)
        var generation = MatrizArtworkGeneration()
        let a = generation.change(to: "A")
        let b = generation.change(to: "B")
        precondition(!generation.accepts(a, track: "A") && generation.accepts(b, track: "B"))
        let retry = generation.change(to: nil)
        precondition(!generation.accepts(b, track: "B") && retry != b)
        let newB = generation.change(to: "B")
        precondition(generation.accepts(newB, track: "B") && !generation.accepts(b, track: "B"))
        var cache = MatrizArtworkCache()
        let urlA = URL(string: "https://i.scdn.co/image/A")!, urlB = URL(string: "https://i.scdn.co/image/B")!
        cache.store([red], for: urlA)
        // Starting B, then skipping to another track on album B must never reuse A's color.
        precondition(cache.colors(for: urlA) == [red] && cache.colors(for: urlB) == nil)
        cache.store([blue, red], for: urlB)
        precondition(cache.colors(for: urlB) == [blue, red] && cache.colors(for: urlA) == nil)
        precondition(MatrizPlayer.select(playing: [], previous: 0) == nil)
        precondition(MatrizPlayer.select(playing: [1], previous: 0) == 1)
        precondition(MatrizPlayer.select(playing: [0], previous: 1) == 0)
        precondition(MatrizPlayer.select(playing: [0, 1], previous: 1) == 1)
        precondition(MatrizPlayer.select(playing: [0, 1], previous: nil) == 0)
        let live = MatrizLiveState.shared
        live.configureArtwork(count: 1, intensity: 1, duration: 3, at: 0)
        live.setArtwork([red, blue, SIMD3(0, 1, 0), SIMD3(1, 1, 0)], at: 0, duration: 3)
        let one = live.artwork(at: 3)
        precondition(one.primary.w == 1 && one.primary == one.secondary && one.primary == one.tertiary && one.primary == one.quaternary)
        precondition(one.primary.x > 0.99 && one.primary.y < 0.01 && one.primary.z < 0.01)
        live.configureArtwork(count: 4, intensity: 1, duration: 3, at: 3)
        let started = live.artwork(at: 3)
        precondition(started.secondary == one.secondary, "Cambiar la cantidad provoca un salto.")
        let four = live.artwork(at: 6)
        precondition(four.secondary.z > 0.99 && four.tertiary.y > 0.99 && four.quaternary.x > 0.99)
        live.configureArtwork(count: 1, intensity: 0, duration: 3, at: 6)
        let neutral = live.artwork(at: 9).primary
        precondition(neutral.w == 1 && abs(neutral.x - neutral.y) < 0.001 && abs(neutral.y - neutral.z) < 0.001,
                     "Colorido cero debe conservar la paleta de portada en grises.")
        live.setArtwork(nil, at: 10, duration: 1)
        precondition(live.artwork(at: 11).primary.w == 0)
        live.configureArtwork(count: 3, intensity: 1, duration: 3, at: 12)
    }
}
