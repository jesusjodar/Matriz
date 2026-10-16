import AppKit
import CryptoKit
import Darwin

// Only state metadata crosses this bridge; prompts, tool arguments and responses are never stored.
enum MatrizAgentState: String, Codable, CaseIterable {
    case idle, running, permission, input, error, completed
    var title: String {
        switch self {
        case .idle: return L("Idle")
        case .running: return L("Running")
        case .permission: return L("Needs permission")
        case .input: return L("Needs input")
        case .error: return L("Error")
        case .completed: return L("Completed")
        }
    }
    var priority: Int {
        switch self { case .permission: return 6; case .input: return 5; case .error: return 4
        case .running: return 3; case .completed: return 2; case .idle: return 1 }
    }
    var color: SIMD3<Float> {
        switch self {
        case .idle: return SIMD3(0.38, 0.42, 0.48)
        case .running: return SIMD3(0.12, 0.48, 0.95)
        case .permission: return SIMD3(1, 0.60, 0.08)
        case .input: return SIMD3(0.68, 0.35, 0.95)
        case .error: return SIMD3(0.96, 0.15, 0.22)
        case .completed: return SIMD3(0.12, 0.82, 0.43)
        }
    }
}

struct MatrizAgentEvent: Codable, Equatable {
    var agent: String
    var session: String
    var state: MatrizAgentState
    var timestamp: Double

    func visible(at now: Double) -> MatrizAgentEvent? {
        let age = now - timestamp
        // shortcut: event leases last 30 minutes; add publisher heartbeats for longer silent turns.
        guard timestamp.isFinite, age >= -5, age < 1800 else { return nil }
        var event = self
        if state == .completed && age > 15 { event.state = .idle }
        if state == .error && age > 60 { return nil }
        return event
    }
}

enum MatrizAgentBridge {
    static let agents = ["codex", "claude", "opencode", "hermes", "lmstudio", "generic"]
    static let names = ["Codex", "Claude Code", "OpenCode", "Hermes", "LM Studio", "Other agents"]
    static var directory: URL {
        if Bundle.main.bundleIdentifier == "com.matriz.wallpaper.extension" { return wallpaperDirectory }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Matriz/AgentEvents")
    }
    static var wallpaperDirectory: URL {
        if Bundle.main.bundleIdentifier == "com.matriz.wallpaper.extension" {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("AgentEvents")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.matriz.wallpaper.extension/Data/Documents/AgentEvents")
    }
    static func name(_ agent: String) -> String {
        guard let index = agents.firstIndex(of: agent) else { return agent }
        return agent == "generic" ? L("Other agents") : names[index]
    }
    static func identifier(agent: String, session: String) -> String {
        SHA256.hash(data: Data((agent + ":" + session).utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func event(agent: String, payload: [String: Any], at now: Double = Date.timeIntervalSinceReferenceDate) -> MatrizAgentEvent? {
        guard agents.contains(agent) else { return nil }
        let properties = payload["properties"] as? [String: Any] ?? [:]
        let extra = payload["extra"] as? [String: Any] ?? [:]
        let kind = payload["hook_event_name"] as? String ?? payload["type"] as? String ?? ""
        var state: MatrizAgentState?
        switch agent {
        case "codex", "claude":
            switch kind {
            case "SessionStart", "SessionEnd", "Interrupt": state = .idle
            case "UserPromptSubmit", "PostToolUse", "PreCompact", "PostCompact": state = .running
            case "PreToolUse": state = (payload["tool_name"] as? String == "AskUserQuestion") ? .input : .running
            case "PermissionRequest": state = .permission
            case "Stop": state = .completed
            case "StopFailure", "PostToolUseFailure": if agent == "claude" { state = .error }
            case "Notification":
                if agent == "claude" {
                    switch payload["notification_type"] as? String {
                    case "permission_prompt": state = .permission
                    case "idle_prompt", "elicitation_dialog": state = .input
                    default: break
                    }
                }
            default: break
            }
        case "opencode":
            switch kind {
            case "session.created", "session.deleted": state = .idle
            case "session.idle": state = .completed
            case "session.error", "session.execution.failed": state = .error
            case "session.execution.started": state = .running
            case "session.execution.succeeded": state = .completed
            case "session.execution.interrupted": state = .idle
            case "permission.asked": state = .permission
            case "question.asked", "form.created": state = .input
            case "permission.replied", "permission.rejected", "question.replied", "question.rejected", "form.replied", "form.cancelled": state = .running
            case "session.status":
                let status = (properties["status"] as? [String: Any])?["type"] as? String
                if status == "busy" || status == "retry" { state = .running }
                if status == "idle" { state = .completed }
            default: break
            }
        case "hermes":
            switch kind {
            case "on_session_start", "on_session_finalize", "agent_loop_stopped": state = .idle
            case "pre_llm_call", "pre_tool_call", "post_tool_call", "on_human_input_resolved", "post_approval_response": state = .running
            case "post_llm_call": state = .completed
            case "pre_approval_request": state = .permission
            case "on_human_input_request": state = extra["kind"] as? String == "approval" ? .permission : .input
            case "on_session_end":
                state = extra["failed"] as? Bool == true ? .error : (extra["completed"] as? Bool == true ? .completed : .idle)
            default: break
            }
        default: break
        }
        guard state != nil else { return nil }
        var session = payload["session_id"] as? String ?? properties["sessionID"] as? String ?? "main"
        if session.isEmpty { session = "main" }
        if agent == "hermes", ["pre_approval_request", "post_approval_response"].contains(kind),
           let key = extra["session_key"] as? String {
            session = "approval:" + key
            if kind == "post_approval_response" { state = .idle }
        }
        guard session.utf8.count <= 1024 else { return nil }
        return MatrizAgentEvent(agent: agent, session: identifier(agent: agent, session: session), state: state!, timestamp: now)
    }
    static func write(_ event: MatrizAgentEvent, to folder: URL = directory) throws {
        guard agents.contains(event.agent), event.session.count == 64,
              event.session.allSatisfy({ $0.isHexDigit }), event.timestamp.isFinite else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let attributes = try manager.attributesOfItem(atPath: folder.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              ((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o777) & 0o077 == 0 else {
            throw CocoaError(.fileWriteNoPermission)
        }
        let path = folder.appendingPathComponent(event.session + ".json")
        if event.agent == "opencode", event.state == .completed,
           let previous = try? Data(contentsOf: path), let old = try? JSONDecoder().decode(MatrizAgentEvent.self, from: previous),
           old.state == .error, event.timestamp - old.timestamp >= 0, event.timestamp - old.timestamp < 2 { return }
        let data = try JSONEncoder().encode(event)
        try data.write(to: path, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    }
    static func latest(in folder: URL = directory, source: String, at now: Double = Date.timeIntervalSinceReferenceDate) -> MatrizAgentEvent? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: folder.path),
              attributes[.type] as? FileAttributeType == .typeDirectory,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              ((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o777) & 0o077 == 0 else { return nil }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { return nil }
        let candidates = files.compactMap { file -> (URL, Date)? in
            guard file.pathExtension == "json", let info = try? file.resourceValues(forKeys: keys),
                  info.isRegularFile == true, info.isSymbolicLink != true, (info.fileSize ?? Int.max) <= 2048 else { return nil }
            return (file, info.contentModificationDate ?? .distantPast)
        }.sorted { $0.1 > $1.1 }.prefix(256)
        return candidates.compactMap { file, _ -> MatrizAgentEvent? in
            guard let data = try? Data(contentsOf: file), let event = try? JSONDecoder().decode(MatrizAgentEvent.self, from: data),
                  agents.contains(event.agent), source == "all" || source == event.agent,
                  file.deletingPathExtension().lastPathComponent == event.session else { return nil }
            return event.visible(at: now)
        }.max {
            $0.state.priority == $1.state.priority ? $0.timestamp < $1.timestamp : $0.state.priority < $1.state.priority
        }
    }
    // Hooks are observers: always return an empty JSON object and never change approval decisions.
    private static func record(_ event: MatrizAgentEvent) throws {
        try write(event)
        // The sandboxed wallpaper receives the same metadata, never chat contents.
        try? write(event, to: wallpaperDirectory)
    }
    static func handleCLI(_ arguments: [String]) -> Bool {
        guard let flag = arguments.first, flag == "--agent-event" || flag == "--agent-hook" else { return false }
        do {
            if flag == "--agent-event" {
                guard (3...4).contains(arguments.count), agents.contains(arguments[1]),
                      let state = MatrizAgentState(rawValue: arguments[2]) else { throw CocoaError(.coderInvalidValue) }
                let session = arguments.count == 4 ? arguments[3] : "main"
                guard session.utf8.count <= 1024 else { throw CocoaError(.coderInvalidValue) }
                try record(MatrizAgentEvent(agent: arguments[1], session: identifier(agent: arguments[1], session: session), state: state,
                                           timestamp: Date.timeIntervalSinceReferenceDate))
            } else {
                guard arguments.count == 2 else { throw CocoaError(.coderInvalidValue) }
                var input = Data()
                while input.count <= 2 * 1024 * 1024 {
                    let chunk = FileHandle.standardInput.readData(ofLength: min(65536, 2 * 1024 * 1024 + 1 - input.count))
                    if chunk.isEmpty { break }
                    input.append(chunk)
                }
                guard input.count <= 2 * 1024 * 1024,
                      let payload = try JSONSerialization.jsonObject(with: input) as? [String: Any] else { throw CocoaError(.coderInvalidValue) }
                if let event = event(agent: arguments[1], payload: payload) { try record(event) }
            }
        } catch {
            if flag == "--agent-event" { fputs("Matriz: unable to write agent state.\n", stderr); exit(1) }
        }
        if flag == "--agent-hook" { print("{}") }
        return true
    }
    static func exportIntegrations(bundle: Bundle = MatrizI18n.bundle) throws -> URL {
        guard let resources = bundle.resourceURL?.appendingPathComponent("AgentIntegrations"),
              let executable = bundle.executableURL else { throw CocoaError(.fileNoSuchFile) }
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Matriz/Integrations/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let quoted = "'" + executable.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        func json(_ value: String) throws -> String {
            String(data: try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes]), encoding: .utf8)!
        }
        var replacements = ["__EXECUTABLE__": try json(executable.path)]
        for agent in ["codex", "claude", "hermes"] { replacements["__" + agent.uppercased() + "_COMMAND__"] = try json(quoted + " --agent-hook " + agent) }
        for file in try FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil) {
            var content = try String(contentsOf: file, encoding: .utf8)
            for (token, value) in replacements { content = content.replacingOccurrences(of: token, with: value) }
            try content.write(to: folder.appendingPathComponent(file.lastPathComponent), atomically: true, encoding: .utf8)
        }
        return folder
    }
}

final class MatrizAgentService {
    private var timer: Timer?
    private var source = "all"
    func configure(active: Bool, source: String) {
        self.source = source
        if !active {
            timer?.invalidate(); timer = nil
            MatrizLiveState.shared.setAgent(nil)
        } else {
            refresh()
            if timer == nil { timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() } }
        }
    }
    private func refresh() { MatrizLiveState.shared.setAgent(MatrizAgentBridge.latest(source: source)) }
    func shutdown() { timer?.invalidate(); timer = nil; MatrizLiveState.shared.setAgent(nil) }
    deinit { timer?.invalidate() }
}
