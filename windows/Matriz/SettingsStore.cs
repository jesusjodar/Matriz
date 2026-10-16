using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Matriz;

public sealed class SettingsStore
{
    public static string Directory => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Matriz");
    public static string Assets => Path.Combine(AppContext.BaseDirectory, "Assets");
    public static JsonArray Schema { get; } = JsonNode.Parse(File.ReadAllText(Path.Combine(Assets, "settings.json")))!["settings"]!.AsArray();
    private static readonly JsonObject Strings = JsonNode.Parse(File.ReadAllText(Path.Combine(Assets, "strings.json")))!.AsObject();
    public JsonObject Values { get; private set; }
    public event Action? Changed;
    public string? LoadError { get; private set; }
    private readonly string path;

    public SettingsStore(string? testPath = null)
    {
        path = testPath ?? Path.Combine(Directory, "settings.json");
        try { Values = Sanitize(File.Exists(path) ? JsonNode.Parse(File.ReadAllText(path))?.AsObject() : null); }
        catch (Exception error) { Values = Sanitize(null); LoadError = error.Message; }
    }
    public static string Text(string key)
    {
        var language = CultureInfo.CurrentUICulture.Name;
        if (!Strings.ContainsKey(language)) language = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;
        return Strings[language]?[key]?.GetValue<string>() ?? Strings["en"]?[key]?.GetValue<string>() ?? key;
    }
    public static JsonObject Sanitize(JsonObject? input, JsonObject? basis = null)
    {
        var result = new JsonObject { ["settingsVersion"] = 2 };
        foreach (var item in Schema)
        {
            var spec = item!.AsObject(); var key = spec["key"]!.GetValue<string>();
            var value = input?[key]; var fallback = basis?[key] ?? spec["default"];
            JsonNode? clean = fallback?.DeepClone();
            if (spec["kind"]!.GetValue<string>() == "boolean" && value is JsonValue boolean && boolean.TryGetValue<bool>(out _)) clean = value.DeepClone();
            if (spec["kind"]!.GetValue<string>() == "color" && value is JsonArray colors && colors.Count == 3 && colors.All(x => TryNumber(x, out _)))
                clean = new JsonArray(colors.Select(x => { TryNumber(x, out var n); return (JsonNode?)JsonValue.Create(Math.Clamp(n, 0, 1)); }).ToArray());
            if (key == "agentSource" && value is JsonValue source && source.TryGetValue<string>(out var name) && spec["choices"]!.AsArray().Any(x => x!.GetValue<string>() == name)) clean = value.DeepClone();
            if (spec.ContainsKey("min") && TryNumber(value, out var v))
            {
                v = Math.Clamp(v, spec["min"]!.GetValue<double>(), spec["max"]!.GetValue<double>());
                if (spec["kind"]!.GetValue<string>() == "choice" || key == "artworkColors") v = Math.Round(v, MidpointRounding.AwayFromZero);
                clean = JsonValue.Create(v);
            }
            result[key] = clean;
        }
        return result;
    }
    private static bool TryNumber(JsonNode? node, out double number)
    {
        number = 0;
        return node is JsonValue value && double.TryParse(value.ToString(), NumberStyles.Float, CultureInfo.InvariantCulture, out number)
            && double.IsFinite(number) && value.GetValueKind() == JsonValueKind.Number;
    }
    public void Set(string key, JsonNode? value)
    {
        var next = Sanitize(new JsonObject { [key] = value }, Values);
        System.IO.Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        if (LoadError != null && File.Exists(path)) File.Copy(path, path + ".backup-" + Guid.NewGuid().ToString("N"));
        var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try { File.WriteAllText(temporary, next.ToJsonString()); File.Move(temporary, path, true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
        Values = next; LoadError = null; Changed?.Invoke();
    }
    public double Number(string key) => Values[key]!.GetValue<double>();
    public bool Enabled(string key) => Values[key]!.GetValue<bool>();
}
