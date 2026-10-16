import Foundation

enum MatrizAgentCheck {
    static func run() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let now = 1000.0
        func event(_ agent: String, _ kind: String, _ session: String = "test") -> MatrizAgentEvent {
            MatrizAgentBridge.event(agent: agent, payload: ["hook_event_name": kind, "type": kind,
                "session_id": session, "properties": ["sessionID": session]], at: now)!
        }
        precondition(event("codex", "PermissionRequest").state == .permission)
        precondition(event("claude", "StopFailure").state == .error)
        precondition(event("opencode", "session.execution.started").state == .running)
        precondition(event("opencode", "form.created").state == .input)
        precondition(event("hermes", "pre_llm_call").state == .running)
        precondition(MatrizAgentBridge.event(agent: "codex", payload: ["type": "unknown"]) == nil)
        let pending = event("codex", "PermissionRequest", "sensitive-session")
        precondition(pending.session.count == 64 && !pending.session.contains("sensitive"))
        try MatrizAgentBridge.write(event("opencode", "session.execution.started"), to: folder)
        try MatrizAgentBridge.write(pending, to: folder)
        precondition(MatrizAgentBridge.latest(in: folder, source: "all", at: now)?.state == .permission)
        precondition(MatrizAgentBridge.latest(in: folder, source: "opencode", at: now)?.state == .running)
        precondition(MatrizAgentBridge.latest(in: folder, source: "all", at: now + 1801) == nil)
        let failed = event("opencode", "session.execution.failed")
        try MatrizAgentBridge.write(failed, to: folder)
        try MatrizAgentBridge.write(event("opencode", "session.execution.succeeded"), to: folder)
        precondition(MatrizAgentBridge.latest(in: folder, source: "opencode", at: now)?.state == .error)
        precondition(failed.visible(at: now + 61) == nil)
        precondition(event("codex", "Stop").visible(at: now + 16)?.state == .idle)
        let approval = MatrizAgentBridge.event(agent: "hermes", payload: ["hook_event_name": "post_approval_response",
            "session_id": "", "extra": ["session_key": "terminal"]], at: now)!
        precondition(approval.state == .idle && approval.session != event("hermes", "pre_llm_call").session)
        var settings = MatrizSettings()
        settings.agentEnabled = true; settings.agentSource = "lmstudio"
        precondition(MatrizSettings(settings.values) == settings)
        precondition(MatrizSettings(["agentSource": "invalid"]).agentSource == "all")
        let live = MatrizLiveState()
        live.setAgent(pending, at: 10)
        precondition(live.agentPalette(at: 11).primary.w == 1)
        live.setAgent(nil, at: 11)
        precondition(live.agentPalette(at: 12).primary.w == 0)
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: folder.path)
        precondition(MatrizAgentBridge.latest(in: folder, source: "all", at: now) == nil)
        do { try MatrizAgentBridge.write(pending, to: folder); preconditionFailure("Unsafe directory accepted") }
        catch {}
        print("Agent mappings, privacy, priorities, leases, preferences and transitions: OK")
    }
}
