using System.Text.Json;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Windowing;
using Microsoft.Web.WebView2.Core;

namespace Matriz;

public sealed class WallpaperWindow : Window
{
    private readonly WebView2 browser = new();
    private readonly SettingsStore settings;
    public event Action<string>? Error;
    private bool ready;
    public bool Ready => ready;
    private nint worker;
    public nint Handle => WinRT.Interop.WindowNative.GetWindowHandle(this);

    public WallpaperWindow(SettingsStore settings)
    {
        this.settings = settings; Title = "Matriz Wallpaper";
        Content = browser;
        if (AppWindow.Presenter is OverlappedPresenter presenter) { presenter.SetBorderAndTitleBar(false, false); presenter.IsResizable = false; presenter.IsMaximizable = false; presenter.IsMinimizable = false; }
        Closed += (_, _) => browser.Close();
    }
    public async Task StartAsync()
    {
        Activate();
        await browser.EnsureCoreWebView2Async();
        var core = browser.CoreWebView2;
        core.Settings.AreDevToolsEnabled = false; core.Settings.AreDefaultContextMenusEnabled = false;
        core.Settings.IsStatusBarEnabled = false; core.Settings.AreBrowserAcceleratorKeysEnabled = false;
        core.SetVirtualHostNameToFolderMapping("matriz.local", Path.Combine(SettingsStore.Assets, "Web"), CoreWebView2HostResourceAccessKind.DenyCors);
        core.PermissionRequested += (_, e) => e.State = CoreWebView2PermissionState.Deny;
        core.NewWindowRequested += (_, e) => e.Handled = true;
        core.DownloadStarting += (_, e) => e.Cancel = true;
        core.NavigationStarting += (_, e) => { if (e.Uri != "https://matriz.local/index.html" && e.Uri != "about:blank") e.Cancel = true; };
        core.WebMessageReceived += (_, e) => {
            if (e.Source != "https://matriz.local/index.html") return;
            try {
                using var message = JsonDocument.Parse(e.WebMessageAsJson);
                var type = message.RootElement.GetProperty("type").GetString();
                if (type == "ready") { ready = true; SendSettings(); }
                if (type == "error") Error?.Invoke(message.RootElement.GetProperty("message").GetString() ?? "WebGL error");
            } catch (JsonException error) { Error?.Invoke(error.Message); }
        };
        browser.Source = new Uri("https://matriz.local/index.html");
        try { worker = Desktop.Attach(this); }
        catch { Close(); throw; }
    }
    public void Maintain()
    {
        if (!Desktop.IsWindow(worker)) worker = Desktop.Attach(this);
        else Desktop.Resize(Handle, worker);
    }
    public void Send(object message) { if (ready) browser.CoreWebView2.PostWebMessageAsJson(JsonSerializer.Serialize(message)); }
    public void SendSettings(bool lowPower = false)
    {
        var values = settings.Values.DeepClone().AsObject();
        if (lowPower) values["quality"] = 0;
        Send(new { type = "settings", settings = values });
    }
}
