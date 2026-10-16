import AppKit
import CoreAudio

@available(macOS 14.2, *)
final class MatrizAudioService {
    private let queue = DispatchQueue(label: "com.matriz.audio", qos: .userInitiated)
    private var tap: AudioObjectID = 0
    private var aggregate: AudioObjectID = 0
    private var ioProc: AudioDeviceIOProcID?
    private var buffer: OpaquePointer?
    private var analysis: MatrizAudioAnalysis?
    private var scratch: [Float] = []
    private var channels = 0
    private var outputName = L("Mac audio output")
    private var timer: DispatchSourceTimer?
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var wanted = false
    private var settings = MatrizSettings()
    private var lowPower = false
    private var generation = 0
    private let delivery = MatrizPublicationGate()
    private var publicationID = 0
    var report: ((String, SIMD4<Float>?) -> Void)?

    func configure(active: Bool, settings: MatrizSettings, lowPower: Bool, retry: Bool = false) {
        let token = delivery.invalidate()
        queue.async { [self] in
            publicationID = token
            self.settings = settings
            if active == wanted && !retry {
                if self.lowPower != lowPower { self.lowPower = lowPower; scheduleTimer() }
                return
            }
            wanted = active
            self.lowPower = lowPower
            generation += 1
            stop()
            if active { start() }
        }
    }
    func shutdown() { _ = delivery.invalidate(); queue.sync { wanted = false; generation += 1; stop() } }
    private func publish(_ status: String, _ audio: SIMD4<Float>? = nil) {
        let token = publicationID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.delivery.accepts(token) else { return }
            self.report?(status, audio)
        }
    }
    private func fail(_ message: String) { stop(); publish(message, .zero) }
    private func require(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            NSLog("Matriz audio: %@ (%d)", operation, status)
            throw NSError(domain: "MatrizAudio", code: Int(status), userInfo: [NSLocalizedDescriptionKey:
                LF("Audio is unavailable (%d). Check its permission and try again.", Int(status))])
        }
    }
    private func read<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, initial: T) throws -> T {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0) }
        try require(status, "No se pudo leer la salida de audio")
        return value
    }
    private func observe(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        let observedGeneration = generation
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self, self.wanted, self.generation == observedGeneration else { return }
            self.generation += 1
            self.stop()
            self.publish(L("Audio output changed; reconnecting…"), .zero)
            self.start()
        }
        try require(AudioObjectAddPropertyListenerBlock(id, &address, queue, block), "No se pudo observar la salida")
        listeners.append((id, address, block))
    }
    private func start() {
        do {
            let hardware = AudioObjectID(kAudioObjectSystemObject)
            let device: AudioObjectID = try read(hardware, kAudioHardwarePropertyDefaultOutputDevice, initial: 0)
            guard device != kAudioObjectUnknown else { throw NSError(domain: "MatrizAudio", code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("No audio output is available.")]) }
            let uid: CFString = try read(device, kAudioDevicePropertyDeviceUID, initial: "" as CFString)
            let name: CFString = try read(device, kAudioObjectPropertyName, initial: L("Mac audio output") as CFString)
            outputName = name as String
            var streamsAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            var size: UInt32 = 0
            try require(AudioObjectGetPropertyDataSize(device, &streamsAddress, 0, nil, &size), "No se pudo leer el formato")
            var streams = [AudioStreamID](repeating: 0, count: Int(size) / MemoryLayout<AudioStreamID>.size)
            guard !streams.isEmpty else { throw NSError(domain: "MatrizAudio", code: 2,
                userInfo: [NSLocalizedDescriptionKey: L("This audio output format is not supported.")]) }
            try require(AudioObjectGetPropertyData(device, &streamsAddress, 0, nil, &size, &streams), "No se pudo leer el stream")
            let description = CATapDescription(excludingProcesses: [], deviceUID: uid as String, stream: 0)
            description.name = "Matriz · Local audio analysis"
            description.isPrivate = true
            description.muteBehavior = .unmuted
            try require(AudioHardwareCreateProcessTap(description, &tap), "No se pudo preparar la captura")
            let format: AudioStreamBasicDescription = try read(tap, kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
            let flags = format.mFormatFlags
            let floating = flags & kAudioFormatFlagIsFloat != 0
            let supportedBits = floating ? [32, 64].contains(format.mBitsPerChannel) : [16, 32].contains(format.mBitsPerChannel)
            let interleavedChannels: UInt32 = flags & kAudioFormatFlagIsNonInterleaved != 0 ? 1 : format.mChannelsPerFrame
            guard format.mFormatID == kAudioFormatLinearPCM, supportedBits,
                  floating || flags & kAudioFormatFlagIsSignedInteger != 0,
                  flags & kAudioFormatFlagIsBigEndian == 0, flags & kAudioFormatFlagIsPacked != 0,
                  format.mBytesPerFrame == format.mBitsPerChannel / 8 * interleavedChannels,
                  (1...8).contains(format.mChannelsPerFrame), format.mSampleRate.isFinite,
                  (8000...192000).contains(format.mSampleRate) else {
                throw NSError(domain: "MatrizAudio", code: 3, userInfo: [NSLocalizedDescriptionKey:
                    L("This audio output format is not supported.")])
            }
            channels = Int(format.mChannelsPerFrame)
            guard let storage = MatrizAudioBufferCreate(format.mChannelsPerFrame, format.mBitsPerChannel, flags) else {
                throw NSError(domain: "MatrizAudio", code: 4, userInfo: [NSLocalizedDescriptionKey: L("Not enough memory to analyze audio.")])
            }
            buffer = storage
            scratch = [Float](repeating: 0, count: MatrizAudioAnalysis.count * channels)
            analysis = MatrizAudioAnalysis(sampleRate: format.mSampleRate, channels: channels)
            let configuration: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Matriz · Private audio",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString,
                                                  kAudioSubTapDriftCompensationKey: true]]]
            try require(AudioHardwareCreateAggregateDevice(configuration as CFDictionary, &aggregate), "No se pudo conectar la captura")
            try require(AudioDeviceCreateIOProcID(aggregate, MatrizAudioIOProc, UnsafeMutableRawPointer(storage), &ioProc),
                        "No se pudo preparar el lector de audio")
            try require(AudioDeviceStart(aggregate, ioProc), "No se pudo iniciar el audio")
            try observe(hardware, kAudioHardwarePropertyDefaultOutputDevice)
            try observe(device, kAudioDevicePropertyDeviceIsAlive)
            try observe(device, kAudioDevicePropertyNominalSampleRate)
            try observe(streams[0], kAudioStreamPropertyVirtualFormat)
            try observe(tap, kAudioTapPropertyFormat)
            publish(LF("No sound from %@. Check audio permission if music is playing.", name as String))
            scheduleTimer()
        } catch { fail(error.localizedDescription) }
    }
    private func scheduleTimer() {
        timer?.cancel()
        timer = nil
        guard wanted, buffer != nil else { return }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: 1.0 / (lowPower ? 15 : 30), leeway: .milliseconds(4))
        source.setEventHandler { [weak self] in self?.tick() }
        timer = source
        source.resume()
    }
    private func tick() {
        guard let buffer, let analysis else { return }
        let count = scratch.withUnsafeMutableBufferPointer {
            MatrizAudioBufferRead(buffer, $0.baseAddress!, UInt32(MatrizAudioAnalysis.count))
        }
        let value = scratch.withUnsafeBufferPointer {
            analysis.process($0, frames: Int(count), at: ProcessInfo.processInfo.systemUptime,
                             sensitivity: settings.audioSensitivity, response: settings.audioResponse)
        } * Float(settings.audioIntensity)
        publish(value.w > 0.005 ? LF("Listening to %@", outputName) : LF("No sound from %@. Check audio permission if music is playing.", outputName), value)
    }
    private func stop() {
        timer?.cancel(); timer = nil
        for (id, var address, block) in listeners { AudioObjectRemovePropertyListenerBlock(id, &address, queue, block) }
        listeners.removeAll()
        if let ioProc, aggregate != 0 {
            AudioDeviceStop(aggregate, ioProc)
            AudioDeviceDestroyIOProcID(aggregate, ioProc)
        }
        ioProc = nil
        if aggregate != 0 { AudioHardwareDestroyAggregateDevice(aggregate); aggregate = 0 }
        if tap != 0 { AudioHardwareDestroyProcessTap(tap); tap = 0 }
        if let buffer { MatrizAudioBufferDestroy(buffer) }
        buffer = nil
        analysis = nil
        scratch = []
    }
}
