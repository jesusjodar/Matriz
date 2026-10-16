import Accelerate
import Foundation

final class MatrizAudioAnalysis {
    static let count = 2048
    private let channels: Int
    private let bandBins: [Range<Int>]
    private let fft: FFTSetup
    private var history: [Float]
    private var window = [Float](repeating: 0, count: count)
    private var input = [Float](repeating: 0, count: count)
    private var real = [Float](repeating: 0, count: count / 2)
    private var imaginary = [Float](repeating: 0, count: count / 2)
    private var power = [Float](repeating: 0, count: count / 2)
    private var filled = 0
    private var lastSamples = -Double.infinity
    private var lastTick: Double?
    private var reference: Float = 0.08
    private var target = SIMD4<Float>.zero
    private(set) var value = SIMD4<Float>.zero
    private var gateOpen = false

    init(sampleRate: Double, channels: Int) {
        bandBins = [(40.0, 250.0), (250.0, 2000.0), (2000.0, 10000.0)].map { low, high in
            let first = max(1, min(Self.count / 2, Int(ceil(low * Double(Self.count) / sampleRate))))
            let last = max(first, min(Self.count / 2, Int(ceil(high * Double(Self.count) / sampleRate))))
            return first..<last
        }
        self.channels = channels
        history = [Float](repeating: 0, count: Self.count * channels)
        fft = vDSP_create_fftsetup(11, FFTRadix(kFFTRadix2))!
        vDSP_hann_window(&window, vDSP_Length(Self.count), Int32(vDSP_HANN_NORM))
    }
    deinit { vDSP_destroy_fftsetup(fft) }

    func process(_ samples: UnsafeBufferPointer<Float>, frames: Int, at now: Double,
                 sensitivity: Double = 0, response: Double = 0.65) -> SIMD4<Float> {
        let dt = min(0.25, max(0, now - (lastTick ?? (now - 1 / 30))))
        lastTick = now
        let validFrames = frames >= 0 && frames <= samples.count / channels ? frames : 0
        let count = min(validFrames, Self.count)
        if count > 0 && samples.count >= count * channels {
            let kept = min(filled, Self.count - count)
            history.withUnsafeMutableBufferPointer { h in
                if kept > 0 { memmove(h.baseAddress!, h.baseAddress! + (filled - kept) * channels, kept * channels * 4) }
                h.baseAddress!.advanced(by: kept * channels).update(from: samples.baseAddress! + (validFrames - count) * channels,
                                                                   count: count * channels)
            }
            filled = kept + count
            lastSamples = now
            if filled == Self.count {
                var bands = SIMD3<Float>.zero
                var energy: Float = 0
                for channel in 0..<channels {
                    for i in 0..<Self.count { input[i] = history[i * channels + channel] }
                    var rms: Float = 0
                    vDSP_rmsqv(input, 1, &rms, vDSP_Length(Self.count))
                    energy += rms * rms / Float(channels)
                    vDSP_vmul(input, 1, window, 1, &input, 1, vDSP_Length(Self.count))
                    real.withUnsafeMutableBufferPointer { r in
                        imaginary.withUnsafeMutableBufferPointer { im in
                            var split = DSPSplitComplex(realp: r.baseAddress!, imagp: im.baseAddress!)
                            input.withUnsafeBufferPointer { buffer in
                                buffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Self.count / 2) {
                                    vDSP_ctoz($0, 2, &split, 1, vDSP_Length(Self.count / 2))
                                }
                            }
                            vDSP_fft_zrip(fft, &split, 1, 11, FFTDirection(FFT_FORWARD))
                            vDSP_zvmags(&split, 1, &power, 1, vDSP_Length(Self.count / 2))
                        }
                    }
                    power.withUnsafeBufferPointer { spectrum in
                        for index in bandBins.indices where !bandBins[index].isEmpty {
                            var sum: Float = 0
                            vDSP_sve(spectrum.baseAddress! + bandBins[index].lowerBound, 1, &sum, vDSP_Length(bandBins[index].count))
                            bands[index] += sum / Float(channels)
                        }
                    }
                }
                let rms = sqrt(energy)
                gateOpen = rms > (gateOpen ? 0.0005623 : 0.001)
                // A bounded, slow reference adapts to quieter recordings without amplifying silence.
                let refTarget = max(0.0126, rms)
                reference += (refTarget - reference) * Float(1 - exp(-dt / (refTarget > reference ? 0.5 : 10)))
                let gain = Float(pow(10, sensitivity / 20)) / max(reference, 0.0126)
                let total = max(bands.x + bands.y + bands.z, 0.000001)
                let strength = gateOpen ? min(1, rms * gain * 0.9) : 0
                target = SIMD4(sqrt(bands.x / total) * strength, sqrt(bands.y / total) * strength,
                               sqrt(bands.z / total) * strength, strength)
            }
        }
        if now - lastSamples > 0.2 { target = .zero; gateOpen = false; filled = 0 }
        let attack = 0.015 + 0.065 * response
        let release = 0.15 + 0.65 * response
        for i in 0..<4 {
            let tau = target[i] > value[i] ? attack : release
            value[i] += (target[i] - value[i]) * Float(1 - exp(-dt / tau))
            if value[i] < 0.00001 { value[i] = 0 }
        }
        return value
    }
}
