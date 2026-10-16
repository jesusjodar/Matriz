using System.Text.Json.Nodes;

namespace Matriz;

internal static class SelfTest
{
    public static int Run()
    {
        var folder = Path.Combine(Path.GetTempPath(), "Matriz-test-" + Guid.NewGuid().ToString("N"));
        var report = Path.Combine(Path.GetTempPath(), "Matriz-self-test.json");
        try {
            System.IO.Directory.CreateDirectory(folder);
            static void Check(bool value, string reason) { if (!value) throw new InvalidOperationException(reason); }
            var defaults = SettingsStore.Sanitize(null);
            Check(defaults["palette"]!.GetValue<double>() == 5 && defaults["shadowLight"]!.GetValue<double>() == .32, "Shared defaults");
            var invalid = SettingsStore.Sanitize(new JsonObject { ["size"] = 100, ["brightness"] = true, ["agentSource"] = "unknown", ["customLight"] = new JsonArray(-1d, .5, 5d) });
            Check(invalid["size"]!.GetValue<double>() == 1.4 && invalid["brightness"]!.GetValue<double>() == 1 && invalid["agentSource"]!.GetValue<string>() == "all", "Validation");
            Check(invalid["customLight"]!.ToJsonString() == "[0,0.5,1]", "Color bounds");
            var store = new SettingsStore(Path.Combine(folder, "settings.json")); store.Set("hue", JsonValue.Create(173d));
            Check(new SettingsStore(Path.Combine(folder, "settings.json")).Number("hue") == 173, "Persistence");
            var hooks = new[] { ("codex", "PermissionRequest", "permission"), ("claude", "StopFailure", "error"), ("opencode", "session.execution.started", "running"), ("hermes", "post_llm_call", "completed") };
            foreach (var (provider, kind, state) in hooks) Check(Agents.Map(provider, new JsonObject { ["hook_event_name"] = kind, ["type"] = kind }) == state, "Hook " + provider);
            Agents.Write("codex", "private-session", "permission", folder); Agents.Write("generic", "test", "running", folder);
            Check(Agents.Latest("all", folder) == "permission" && Agents.Latest("generic", folder) == "running", "Agent priorities");
            Check(Agents.ID("codex", "private-session").Length == 64, "Hashed session IDs");
            foreach (var file in new[] { "Web/index.html", "Web/host.js", "Web/matriz-background.js", "strings.json" }) Check(File.Exists(Path.Combine(SettingsStore.Assets, file)), "Missing asset " + file);
            File.WriteAllText(report, new JsonObject { ["success"] = true, ["checks"] = "settings, validation, persistence, hooks, priorities, hashing, assets" }.ToJsonString());
            return 0;
        } catch (Exception error) { File.WriteAllText(report, new JsonObject { ["success"] = false, ["error"] = error.ToString() }.ToJsonString()); return 1; }
        finally { if (System.IO.Directory.Exists(folder)) System.IO.Directory.Delete(folder, true); }
    }
}
