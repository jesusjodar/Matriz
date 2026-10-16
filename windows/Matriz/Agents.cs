using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace Matriz;

public static class Agents
{
    public static readonly string[] Providers = ["codex", "claude", "opencode", "hermes", "lmstudio", "generic"];
    public static readonly string[] States = ["idle", "completed", "running", "error", "input", "permission"];
    private static string Folder => Path.Combine(SettingsStore.Directory, "AgentEvents");
    private static double Now => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000d - 978307200;
    public static string ID(string provider, string session) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(provider + ":" + session))).ToLowerInvariant();
    public static int? HandleCLI(string[] args)
    {
        if (args.Length == 0 || args[0] is not ("--agent-event" or "--agent-hook")) return null;
        var hook = args[0] == "--agent-hook";
        try {
            if (args.Length < 2 || !Providers.Contains(args[1])) throw new ArgumentException();
            string? state; var session = "main";
            if (hook) {
                if (args.Length != 2) throw new ArgumentException();
                using var input = Console.OpenStandardInput(); using var buffer = new MemoryStream();
                var bytes = new byte[65536]; int count;
                while ((count = input.Read(bytes)) > 0) { if (buffer.Length + count > 2 * 1024 * 1024) throw new ArgumentException(); buffer.Write(bytes, 0, count); }
                var payload = JsonNode.Parse(buffer.ToArray())!.AsObject();
                state = Map(args[1], payload);
                session = payload["session_id"]?.GetValue<string>() ?? payload["properties"]?["sessionID"]?.GetValue<string>() ?? "main";
                if (string.IsNullOrEmpty(session)) session = "main";
                var kind = payload["hook_event_name"]?.GetValue<string>();
                if (args[1] == "hermes" && (kind is "pre_approval_request" or "post_approval_response") && payload["extra"]?["session_key"] is JsonNode key) {
                    session = "approval:" + key.GetValue<string>(); if (kind == "post_approval_response") state = "idle";
                }
            } else {
                if (args.Length is < 3 or > 4 || !States.Contains(args[2])) throw new ArgumentException();
                state = args[2]; if (args.Length == 4) session = args[3];
            }
            if (Encoding.UTF8.GetByteCount(session) > 1024) throw new ArgumentException();
            if (state != null) Write(args[1], session, state, Folder);
        } catch { if (!hook) return 1; }
        if (hook) Console.WriteLine("{}");
        return 0;
    }
    public static string? Map(string provider, JsonObject p)
    {
        var kind = p["hook_event_name"]?.GetValue<string>() ?? p["type"]?.GetValue<string>();
        if (provider is "codex" or "claude") return kind switch {
            "SessionStart" or "SessionEnd" or "Interrupt" => "idle",
            "UserPromptSubmit" or "PostToolUse" or "PreCompact" or "PostCompact" => "running",
            "PreToolUse" => p["tool_name"]?.GetValue<string>() == "AskUserQuestion" ? "input" : "running",
            "PermissionRequest" => "permission", "Stop" => "completed",
            "StopFailure" or "PostToolUseFailure" when provider == "claude" => "error",
            "Notification" when provider == "claude" => p["notification_type"]?.GetValue<string>() switch { "permission_prompt" => "permission", "idle_prompt" or "elicitation_dialog" => "input", _ => null }, _ => null };
        if (provider == "hermes") return kind switch {
            "on_session_start" or "on_session_finalize" or "agent_loop_stopped" => "idle",
            "pre_llm_call" or "pre_tool_call" or "post_tool_call" or "post_approval_response" or "on_human_input_resolved" => "running",
            "pre_approval_request" => "permission", "on_human_input_request" => "input", "post_llm_call" => "completed",
            "on_session_end" => p["extra"]?["failed"]?.GetValue<bool>() == true ? "error" : p["extra"]?["completed"]?.GetValue<bool>() == true ? "completed" : "idle", _ => null };
        if (provider == "opencode") return kind switch {
            "session.created" or "session.deleted" or "session.execution.interrupted" => "idle",
            "session.execution.started" or "permission.replied" or "permission.rejected" or "question.replied" or "question.rejected" or "form.replied" or "form.cancelled" => "running",
            "permission.asked" => "permission", "question.asked" or "form.created" => "input",
            "session.idle" or "session.execution.succeeded" => "completed", "session.error" or "session.execution.failed" => "error",
            "session.status" => p["properties"]?["status"]?["type"]?.GetValue<string>() switch { "busy" or "retry" => "running", "idle" => "completed", _ => null }, _ => null };
        return null;
    }
    public static void Write(string provider, string session, string state, string folder)
    {
        if (!Providers.Contains(provider) || !States.Contains(state) || Encoding.UTF8.GetByteCount(session) > 1024) throw new ArgumentException();
        System.IO.Directory.CreateDirectory(folder); var path = Path.Combine(folder, ID(provider, session) + ".json");
        if (provider == "opencode" && state == "completed" && File.Exists(path)) {
            var old = JsonNode.Parse(File.ReadAllText(path));
            if (old?["state"]?.GetValue<string>() == "error" && Now - old["timestamp"]!.GetValue<double>() < 2) return;
        }
        var value = new JsonObject { ["agent"] = provider, ["session"] = ID(provider, session), ["state"] = state, ["timestamp"] = Now };
        var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try { File.WriteAllText(temporary, value.ToJsonString()); File.Move(temporary, path, true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    public static string? Latest(string source, string? folder = null, double? now = null)
    {
        folder ??= Folder; if (!System.IO.Directory.Exists(folder)) return null;
        var candidates = new List<(string State, double Time)>();
        foreach (var file in new DirectoryInfo(folder).EnumerateFiles("*.json").OrderByDescending(x => x.LastWriteTimeUtc).Take(256)) {
            try {
                if (file.Length > 2048 || file.Attributes.HasFlag(FileAttributes.ReparsePoint)) continue;
                var p = JsonNode.Parse(File.ReadAllText(file.FullName))!; var provider = p["agent"]!.GetValue<string>(); var state = p["state"]!.GetValue<string>();
                var time = p["timestamp"]!.GetValue<double>(); var age = (now ?? Now) - time;
                if (!Providers.Contains(provider) || source != "all" && source != provider || !States.Contains(state) || !double.IsFinite(time) || age < -5 || age >= 1800 || age > 60 && state == "error" || p["session"]!.GetValue<string>() + ".json" != file.Name) continue;
                if (age > 15 && state == "completed") state = "idle";
                candidates.Add((state, time));
            } catch (Exception e) when (e is IOException or System.Text.Json.JsonException or InvalidOperationException or NullReferenceException) { }
        }
        return candidates.OrderByDescending(x => Array.IndexOf(States, x.State)).ThenByDescending(x => x.Time).Select(x => x.State).FirstOrDefault();
    }
    public static string Export()
    {
        var folder = Path.Combine(SettingsStore.Directory, "Integrations", Guid.NewGuid().ToString("N")); System.IO.Directory.CreateDirectory(folder);
        var executable = Environment.ProcessPath!;
        File.WriteAllText(Path.Combine(folder, "matriz-hook.ps1"), "[Console]::InputEncoding = [Text.UTF8Encoding]::new()\n& '" + executable.Replace("'", "''") + "' --agent-hook $args[0]\nexit $LASTEXITCODE\n");
        foreach (var file in System.IO.Directory.EnumerateFiles(Path.Combine(SettingsStore.Assets, "Integrations"))) {
            var content = File.ReadAllText(file).Replace("__EXECUTABLE__", System.Text.Json.JsonSerializer.Serialize(executable));
            foreach (var provider in new[] { "codex", "claude", "hermes" }) content = content.Replace("__" + provider.ToUpperInvariant() + "_COMMAND__", System.Text.Json.JsonSerializer.Serialize("powershell.exe -NoProfile -NonInteractive -File \"" + Path.Combine(folder, "matriz-hook.ps1") + "\" " + provider));
            File.WriteAllText(Path.Combine(folder, Path.GetFileName(file)), content);
        }
        return folder;
    }
}
