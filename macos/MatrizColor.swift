import Foundation
import CoreGraphics
import ImageIO
import simd

enum MatrizColor {
    static let maximumBytes = 8 * 1024 * 1024
    static func linear(_ x: Float) -> Float { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
    static func display(_ x: Float) -> Float { x <= 0.0031308 ? x * 12.92 : 1.055 * pow(max(0, x), 1 / 2.4) - 0.055 }
    static func manualPalette(_ settings: MatrizSettings) -> MatrizArtworkColors {
        let colors: [SIMD3<Float>]
        switch settings.palette {
        case 0: colors = [SIMD3(0.06,0.16,0.6), SIMD3(0.10,0.24,0.68), SIMD3(0.04,0.10,0.36), SIMD3(0.08,0.25,0.55)]
        case 2: colors = [SIMD3(0.10,0.24,0.68), SIMD3(0.025,0.48,0.63), SIMD3(0.08,0.20,0.48), SIMD3(0.08,0.52,0.53)]
        case 3: colors = [SIMD3(0.08,0.48,0.32), SIMD3(0.10,0.23,0.46), SIMD3(0.30,0.75,0.52), SIMD3(0.08,0.35,0.45)]
        case 4: colors = [SIMD3(0.76,0.20,0.12), SIMD3(0.42,0.09,0.43), SIMD3(0.97,0.49,0.20), SIMD3(0.75,0.16,0.36)]
        case 5: colors = [SIMD3(0.63,0.12,0.45), SIMD3(0.30,0.13,0.56), SIMD3(0.94,0.36,0.57), SIMD3(0.49,0.12,0.52)]
        case 6: colors = [SIMD3(0.67,0.32,0.06), SIMD3(0.38,0.12,0.035), SIMD3(0.96,0.65,0.22), SIMD3(0.60,0.24,0.05)]
        case 7: colors = [SIMD3(repeating:0.44), SIMD3(repeating:0.30), SIMD3(repeating:0.70), SIMD3(repeating:0.22)]
        case 8: colors = [settings.customLight, settings.customDeep, settings.customSoft, settings.customAccent].map { SIMD3(Float($0.x),Float($0.y),Float($0.z)) }
        default: colors = [SIMD3(0.10,0.24,0.68), SIMD3(0.24,0.15,0.55), SIMD3(0.025,0.48,0.63), SIMD3(0.14,0.10,0.44)]
        }
        let angle = Float(settings.hue * .pi / 180)
        let c = cos(angle), s = sin(angle) / sqrt(Float(3)), t = (1 - c) / 3
        func rotate(_ color: SIMD3<Float>) -> SIMD4<Float> {
            var rgb = simd_max(.zero, color * c + simd_cross(SIMD3(repeating:s),color) + SIMD3(repeating:simd_dot(color,SIMD3(repeating:t))))
            rgb /= max(1,max(rgb.x,max(rgb.y,rgb.z)))
            return SIMD4(rgb.x,rgb.y,rgb.z,1)
        }
        return MatrizArtworkColors(primary: rotate(colors[0]), secondary: rotate(colors[1]), tertiary: rotate(colors[2]), quaternary: rotate(colors[3]))
    }
    static func lab(_ c: SIMD3<Float>) -> SIMD3<Float> {
        let l = cbrt(0.4122214708 * c.x + 0.5363325363 * c.y + 0.0514459929 * c.z)
        let m = cbrt(0.2119034982 * c.x + 0.6806995451 * c.y + 0.1073969566 * c.z)
        let s = cbrt(0.0883024619 * c.x + 0.2817188376 * c.y + 0.6299787005 * c.z)
        return SIMD3(0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s)
    }
    static func rgb(_ c: SIMD3<Float>) -> SIMD3<Float> {
        func convert(_ scale: Float) -> SIMD3<Float> {
            let a = c.x + (0.3963377774 * c.y + 0.2158037573 * c.z) * scale
            let b = c.x - (0.1055613458 * c.y + 0.0638541728 * c.z) * scale
            let d = c.x - (0.0894841775 * c.y + 1.291485548 * c.z) * scale
            let l = a*a*a, m = b*b*b, s = d*d*d
            return SIMD3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                         -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                         -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)
        }
        func inGamut(_ rgb: SIMD3<Float>) -> Bool {
            min(rgb.x, min(rgb.y, rgb.z)) >= -0.00001 && max(rgb.x, max(rgb.y, rgb.z)) <= 1.00001
        }
        let original = convert(1)
        if inGamut(original) { return simd_clamp(original, .zero, SIMD3(repeating: 1)) }
        // Reducir croma en OKLab evita cambiar el matiz al saturar o mezclar portadas.
        var low: Float = 0, high: Float = 1
        for _ in 0..<10 {
            let middle = (low + high) * 0.5
            if inGamut(convert(middle)) { low = middle } else { high = middle }
        }
        return simd_clamp(convert(low), .zero, SIMD3(repeating: 1))
    }
    static func extract(_ data: Data) -> [SIMD3<Float>]? {
        guard data.count <= maximumBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 8192, height <= 8192, width * height <= 32_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 64,
                kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: 64, height: 64, bitsPerComponent: 8,
                bytesPerRow: 64 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
            let p = bytes.bindMemory(to: UInt8.self)
            var weights = [Float](repeating: 0, count: 125)
            var sums = [SIMD3<Float>](repeating: .zero, count: 125)
            for i in stride(from: 0, to: p.count, by: 4) {
                let alpha = Float(p[i + 3]) / 255
                if alpha < 0.8 { continue }
                let c = SIMD3(Float(p[i]), Float(p[i + 1]), Float(p[i + 2])) / (255 * alpha)
                let linear = SIMD3(Self.linear(c.x), Self.linear(c.y), Self.linear(c.z))
                let lab = Self.lab(linear)
                let angle = atan2(lab.z, lab.y) + .pi
                let hue = min(23, max(0, Int(angle / (2 * .pi) * 24)))
                let lightness = min(4, max(0, Int(lab.x * 5)))
                let chroma = simd_length(SIMD2(lab.y, lab.z))
                let bucket = chroma < 0.035 ? 120 + lightness : hue * 5 + lightness
                // La superficie conserva negros, blancos y pasteles; el croma ayuda a rescatar acentos.
                let weight = alpha * (1 + min(chroma, 0.3) * 2)
                weights[bucket] += weight
                sums[bucket] += linear * weight
            }
            let minimumWeight = max(1, weights.reduce(0, +) * 0.005)
            let ranked = weights.indices.sorted { weights[$0] == weights[$1] ? $0 < $1 : weights[$0] > weights[$1] }
            var colors: [SIMD3<Float>] = []
            for bucket in ranked where weights[bucket] > minimumWeight {
                let color = sums[bucket] / weights[bucket]
                // Nearby hue buckets should not occupy several slots with almost the same tone.
                if colors.allSatisfy({ simd_distance(Self.lab($0), Self.lab(color)) >= 0.085 }) { colors.append(color) }
                if colors.count == 4 { break }
            }
            return colors.isEmpty ? nil : colors
        }
    }
}

struct MatrizColorTransition {
    private var from = SIMD4<Float>.zero
    private var to = SIMD4<Float>.zero
    private var start = 0.0
    private var duration = 3.0
    private func interpolated(at now: Double) -> SIMD4<Float> {
        let t = Float(min(1, max(0, (now - start) / duration)))
        let eased = t * t * (3 - 2 * t)
        return from + (to - from) * eased
    }
    mutating func set(_ color: SIMD3<Float>?, at now: Double, duration: Double) {
        let current = interpolated(at: now)
        let lab = color.map(MatrizColor.lab) ?? SIMD3(current.x, current.y, current.z)
        from = current
        // Fading in from zero should not sweep from black through unrelated hues.
        if current.w == 0 { from = SIMD4(lab.x, lab.y, lab.z, 0) }
        to = SIMD4(lab.x, lab.y, lab.z, color == nil ? 0 : 1)
        start = now
        self.duration = max(0.001, duration)
    }
    func value(at now: Double, intensity: Float) -> SIMD4<Float> {
        let sample = interpolated(at: now)
        let rgb = MatrizColor.rgb(SIMD3(sample.x, sample.y, sample.z))
        return SIMD4(rgb.x, rgb.y, rgb.z, sample.w * intensity)
    }
    func displayValue(at now: Double, colorIntensity: Float) -> SIMD4<Float> {
        let sample = interpolated(at: now)
        let rgb = MatrizColor.rgb(SIMD3(sample.x, sample.y * colorIntensity, sample.z * colorIntensity))
        return SIMD4(MatrizColor.display(rgb.x), MatrizColor.display(rgb.y), MatrizColor.display(rgb.z), sample.w)
    }
}

// A response is accepted only while it still belongs to the selected, playing track.
struct MatrizArtworkGeneration {
    private(set) var value = 0
    private(set) var track: String?
    mutating func change(to track: String?) -> Int {
        value += 1
        self.track = track
        return value
    }
    func accepts(_ generation: Int, track: String) -> Bool { generation == value && track == self.track }
}

struct MatrizArtworkCache {
    private var entry: (URL, [SIMD3<Float>])?
    func colors(for url: URL) -> [SIMD3<Float>]? { entry?.0 == url ? entry?.1 : nil }
    mutating func store(_ colors: [SIMD3<Float>], for url: URL) { entry = (url, colors) }
}

struct MatrizArtworkColors {
    var primary = SIMD4<Float>.zero
    var secondary = SIMD4<Float>.zero
    var tertiary = SIMD4<Float>.zero
    var quaternary = SIMD4<Float>.zero
}
