import AppKit
import Carbon

private func code(_ text: String) -> FourCharCode { text.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }

enum MatrizPlayer {
    static func select(playing: [Int], previous: Int?) -> Int? {
        if let previous, playing.contains(previous) { return previous }
        return playing.first
    }
    static func bundleID(_ source: Int) -> String { source == 1 ? "com.spotify.client" : "com.apple.Music" }
    static func name(_ source: Int) -> String { source == 1 ? "Spotify" : L("Music") }
    static func property(_ name: String, in container: NSAppleEventDescriptor = .null()) -> NSAppleEventDescriptor {
        let object = NSAppleEventDescriptor.record()
        object.setDescriptor(NSAppleEventDescriptor(typeCode: typeProperty), forKeyword: AEKeyword(keyAEDesiredClass))
        object.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        object.setDescriptor(NSAppleEventDescriptor(enumCode: OSType(formPropertyID)), forKeyword: AEKeyword(keyAEKeyForm))
        object.setDescriptor(NSAppleEventDescriptor(typeCode: code(name)), forKeyword: AEKeyword(keyAEKeyData))
        return object.coerce(toDescriptorType: typeObjectSpecifier)!
    }
    static func artwork(in track: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        let object = NSAppleEventDescriptor.record()
        object.setDescriptor(NSAppleEventDescriptor(typeCode: code("cArt")), forKeyword: AEKeyword(keyAEDesiredClass))
        object.setDescriptor(track, forKeyword: AEKeyword(keyAEContainer))
        object.setDescriptor(NSAppleEventDescriptor(enumCode: OSType(formAbsolutePosition)), forKeyword: AEKeyword(keyAEKeyForm))
        object.setDescriptor(NSAppleEventDescriptor(int32: 1), forKeyword: AEKeyword(keyAEKeyData))
        return property("pRaw", in: object.coerce(toDescriptorType: typeObjectSpecifier)!)
    }
    static func permission(_ target: NSAppleEventDescriptor, prompt: Bool) -> OSStatus {
        AEDeterminePermissionToAutomateTarget(target.aeDesc!, typeWildCard, typeWildCard, prompt)
    }
    static func get(_ object: NSAppleEventDescriptor, target: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(eventClass: kAECoreSuite, eventID: kAEGetData, targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(object, forKeyword: keyDirectObject)
        let options = NSAppleEventDescriptor.SendOptions(rawValue: UInt(kAEWaitReply | kAENeverInteract | kAEDoNotPromptForUserConsent))
        let reply = try event.sendEvent(options: options, timeout: 1)
        if let error = reply.paramDescriptor(forKeyword: keyErrorNumber), error.int32Value != 0 {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(error.int32Value))
        }
        guard let value = reply.paramDescriptor(forKeyword: keyDirectObject) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errAEDescNotFound))
        }
        return value
    }
}

final class MatrizArtworkDownload: NSObject, URLSessionDataDelegate {
    private var data = Data()
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var completion: ((Data?) -> Void)?
    static func valid(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host != nil && url.user == nil && url.password == nil
    }
    init(url: URL, queue: DispatchQueue, completion: @escaping (Data?) -> Void) {
        super.init()
        self.completion = completion
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.underlyingQueue = queue
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        task = session?.dataTask(with: url)
        task?.resume()
    }
    func cancel() { completion = nil; task?.cancel(); session?.invalidateAndCancel(); session = nil }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.map(Self.valid) == true ? request : nil)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let valid = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } == true
            && response.expectedContentLength <= Int64(MatrizColor.maximumBytes)
            && response.mimeType?.hasPrefix("image/") == true
        completionHandler(valid ? .allow : .cancel)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard self.data.count <= MatrizColor.maximumBytes - data.count else { dataTask.cancel(); return }
        self.data.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let callback = completion
        completion = nil
        callback?(error == nil ? data : nil)
        session.finishTasksAndInvalidate()
        self.session = nil
    }
}

final class MatrizArtworkService {
    private let queue = DispatchQueue(label: "com.matriz.artwork", qos: .utility)
    private let delivery = MatrizPublicationGate()
    private var publicationID = 0
    private var timer: DispatchSourceTimer?
    private var download: MatrizArtworkDownload?
    private var active = false
    private var source: Int?
    private var permissions: [pid_t: (status: OSStatus, checked: Double)] = [:]
    private var generation = MatrizArtworkGeneration()
    private var missingSince: Double?
    private var cleared = true
    private var cache = MatrizArtworkCache()
    var report: ((String, [SIMD3<Float>]?, Bool) -> Void)?
    var permissionFinished: (() -> Void)?

    func configure(active: Bool) {
        let token = delivery.invalidate()
        queue.async { [self] in
            publicationID = token
            guard self.active != active else { return }
            self.active = active
            stop()
            if active { startTimer() }
        }
    }
    private func running() -> [(Int, NSRunningApplication)] {
        [0, 1].compactMap { source in
            NSRunningApplication.runningApplications(withBundleIdentifier: MatrizPlayer.bundleID(source)).first.map { (source, $0) }
        }
    }
    func connect() {
        queue.async { [self] in
            defer { DispatchQueue.main.async { [weak self] in self?.permissionFinished?() } }
            guard active else { return }
            let players = running()
            guard !players.isEmpty else { publish(L("Open Music or Spotify, then authorize the player.")); return }
            for (_, app) in players {
                let status = MatrizPlayer.permission(NSAppleEventDescriptor(processIdentifier: app.processIdentifier), prompt: true)
                permissions[app.processIdentifier] = (status, ProcessInfo.processInfo.systemUptime)
            }
            download?.cancel(); download = nil
            _ = generation.change(to: nil)
            missingSince = nil
            poll()
        }
    }
    func shutdown() { _ = delivery.invalidate(); queue.sync { active = false; stop() } }
    private func publish(_ status: String, color: [SIMD3<Float>]? = nil, changed: Bool = false) {
        let token = publicationID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.delivery.accepts(token) else { return }
            self.report?(status, color, changed)
        }
    }
    private func stop() {
        timer?.cancel(); timer = nil
        download?.cancel(); download = nil
        _ = generation.change(to: nil)
        source = nil; missingSince = nil; cleared = true
        cache = MatrizArtworkCache(); permissions.removeAll()
        publish(L("Album colors are idle"), changed: true)
    }
    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 2, leeway: .milliseconds(300))
        timer.setEventHandler { [weak self] in self?.poll() }
        self.timer = timer; timer.resume()
    }
    private func unavailable(_ message: String, invalidate: Bool = true) {
        if invalidate && generation.track != nil { _ = generation.change(to: nil); download?.cancel(); download = nil }
        let now = ProcessInfo.processInfo.systemUptime
        if missingSince == nil { missingSince = now }
        if !cleared && now - missingSince! >= 2 {
            cleared = true; publish(message, changed: true)
        } else { publish(message) }
    }
    private func accept(_ data: Data?, token: Int, track: String, source: Int, url: URL? = nil) {
        guard active, generation.accepts(token, track: track) else { return }
        if let color = data.flatMap(MatrizColor.extract) {
            if let url { cache.store(color, for: url) }
            missingSince = nil; cleared = false
            publish(LF("Using %@ album colors", MatrizPlayer.name(source)), color: color, changed: true)
        } else { unavailable(L("No artwork available; using your palette."), invalidate: false) }
    }
    private func poll() {
        guard active else { return }
        let players = running()
        let pids = Set(players.map { $0.1.processIdentifier })
        permissions = permissions.filter { pids.contains($0.key) }
        var playing: [Int] = []
        var needsPermission = false
        for (candidate, app) in players {
            let pid = app.processIdentifier
            let target = NSAppleEventDescriptor(processIdentifier: pid)
            let now = ProcessInfo.processInfo.systemUptime
            if permissions[pid].map({ now - $0.checked > ($0.status == noErr ? 60 : 5) }) ?? true {
                permissions[pid] = (MatrizPlayer.permission(target, prompt: false), now)
            }
            guard permissions[pid]?.status == noErr else { needsPermission = true; continue }
            do {
                if try MatrizPlayer.get(MatrizPlayer.property("pPlS"), target: target).enumCodeValue == code("kPSP") { playing.append(candidate) }
            } catch {
                let status = OSStatus((error as NSError).code)
                if status == errAEEventNotPermitted || status == errAEEventWouldRequireUserConsent {
                    permissions[pid] = (status, now); needsPermission = true
                }
            }
        }
        guard let selected = MatrizPlayer.select(playing: playing, previous: source),
              let app = players.first(where: { $0.0 == selected })?.1 else {
            unavailable(players.isEmpty ? L("Open Music or Spotify to use album colors.")
                : (needsPermission ? L("Authorize open players to read their artwork.")
                    : L("Nothing is playing; returning to your palette.")))
            return
        }
        source = selected
        let target = NSAppleEventDescriptor(processIdentifier: app.processIdentifier)
        var readingArtwork = false
        do {
            let current = MatrizPlayer.property("pTrk")
            guard let id = try MatrizPlayer.get(MatrizPlayer.property(selected == 1 ? "ID  " : "pPIS", in: current), target: target).stringValue,
                  !id.isEmpty else { unavailable(L("This track has no accessible artwork.")); return }
            let track = "\(app.processIdentifier):\(selected):\(id)"
            if generation.track == track {
                if missingSince != nil { unavailable(L("No artwork available; using your palette."), invalidate: false) }
                return
            }
            let token = generation.change(to: track)
            readingArtwork = true
            download?.cancel(); download = nil; missingSince = nil
            if selected == 1 {
                guard let address = try MatrizPlayer.get(MatrizPlayer.property("aUrl", in: current), target: target).stringValue,
                      let url = URL(string: address), MatrizArtworkDownload.valid(url) else {
                    unavailable(L("Spotify has no secure artwork available."), invalidate: false); return
                }
                if let color = cache.colors(for: url) {
                    cleared = false
                    publish(LF("Using %@ album colors", "Spotify"), color: color, changed: true)
                } else {
                    publish(L("Spotify detected; reading artwork…"))
                    download = MatrizArtworkDownload(url: url, queue: queue) { [weak self] data in
                        self?.accept(data, token: token, track: track, source: selected, url: url)
                    }
                }
            } else {
                let data = try MatrizPlayer.get(MatrizPlayer.artwork(in: current), target: target).data
                accept(data, token: token, track: track, source: selected)
            }
        } catch {
            unavailable(L("No artwork available; using your palette."), invalidate: !readingArtwork)
        }
    }
}
