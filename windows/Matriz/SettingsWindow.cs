using System.Text.Json.Nodes;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Windows.UI;
using Path = System.IO.Path;

namespace Matriz;

public sealed class SettingsWindow : Window
{
    private readonly SettingsStore settings = new();
    private readonly NavigationView navigation = new() { PaneDisplayMode = NavigationViewPaneDisplayMode.Top, IsSettingsVisible = false, IsBackButtonVisible = NavigationViewBackButtonVisible.Collapsed };
    private readonly StackPanel content = new() { Spacing = 16, Padding = new Thickness(24), MaxWidth = 900, HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly InfoBar status = new() { IsOpen = false, IsClosable = true, Severity = InfoBarSeverity.Warning };
    private readonly Microsoft.UI.Dispatching.DispatcherQueueTimer timer;
    private readonly Microsoft.UI.Dispatching.DispatcherQueueTimer audioTimer;
    private readonly MediaService media;
    private WallpaperWindow? wallpaper;
    private bool paused, power;
    private string? agent;
    private readonly nint handle;

    public SettingsWindow()
    {
        Title = "Matriz";
        AppWindow.Resize(new Windows.Graphics.SizeInt32(840, 820));
        handle = WinRT.Interop.WindowNative.GetWindowHandle(this);
        media = new MediaService(message => ShowError(message), message => wallpaper?.Send(message));
        var root = new Grid(); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition());
        root.Children.Add(status); Grid.SetRow(navigation, 1); root.Children.Add(navigation);
        navigation.Content = new ScrollViewer { Content = content, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
        foreach (var group in SettingsStore.Schema.Select(x => x!["group"]!.GetValue<string>()).Distinct()) navigation.MenuItems.Add(new NavigationViewItem { Content = SettingsStore.Text(group), Tag = group });
        navigation.SelectionChanged += (_, e) => ShowGroup((string)((NavigationViewItem)e.SelectedItem).Tag);
        Content = root; navigation.SelectedItem = navigation.MenuItems[0];
        settings.Changed += () => { wallpaper?.SendSettings(power); media.Update(settings); };
        timer = DispatcherQueue.CreateTimer(); timer.Interval = TimeSpan.FromSeconds(1); timer.Tick += (_, _) => Tick();
        audioTimer = DispatcherQueue.CreateTimer(); audioTimer.Interval = TimeSpan.FromSeconds(1.0 / 30); audioTimer.Tick += (_, _) => {
            wallpaper?.Send(new { type = "audio", bands = media.Audio(settings) });
        };
        timer.Start(); audioTimer.Start();
        Closed += (_, _) => { timer.Stop(); audioTimer.Stop(); media.Dispose(); wallpaper?.Close(); Application.Current.Exit(); };
        if (settings.LoadError != null) ShowError("Settings were not overwritten: " + settings.LoadError);
        DispatcherQueue.TryEnqueue(async () => await StartWallpaper());
    }
    private void ShowError(string message) { DispatcherQueue.TryEnqueue(() => { status.Message = message; status.IsOpen = true; }); }
    private async Task StartWallpaper()
    {
        if (wallpaper != null) return;
        var candidate = new WallpaperWindow(settings); candidate.Error += ShowError;
        try { await candidate.StartAsync(); wallpaper = candidate; Activate(); }
        catch (Exception error) { candidate.Close(); ShowError(error.Message + " · " + "Check Microsoft Edge WebView2 Runtime and Explorer."); }
    }
    private void Tick()
    {
        try {
            wallpaper?.Maintain();
            var suspend = paused || Desktop.Remote || !Desktop.SessionVisible || Desktop.FullscreenOther(handle, wallpaper?.Handle ?? 0);
            wallpaper?.Send(new { type = "pause", value = suspend });
            var saving = Desktop.BatterySaver;
            if (saving != power) { power = saving; wallpaper?.SendSettings(power); }
            media.SetActive(!suspend, settings);
            var next = settings.Enabled("agentEnabled") ? Agents.Latest(settings.Values["agentSource"]!.GetValue<string>()) : null;
            if (next != agent) { agent = next; wallpaper?.Send(new { type = "agent", state = next }); }
        } catch (Exception error) { ShowError(error.Message); }
    }
    private void ShowGroup(string group)
    {
        content.Children.Clear();
        foreach (var item in SettingsStore.Schema.Where(x => x!["group"]!.GetValue<string>() == group)) {
            var spec = item!.AsObject(); var key = spec["key"]!.GetValue<string>(); var label = SettingsStore.Text(spec["label"]!.GetValue<string>());
            var panel = new StackPanel { Spacing = 8 };
            var border = new Border { Child = panel, Padding = new Thickness(16), CornerRadius = new CornerRadius(8), Background = (Brush)Application.Current.Resources["CardBackgroundFillColorDefaultBrush"] };
            var kind = spec["kind"]!.GetValue<string>();
            if (kind == "boolean") {
                var toggle = new ToggleSwitch { Header = label, IsOn = settings.Enabled(key) };
                toggle.Toggled += (_, _) => Save(key, JsonValue.Create(toggle.IsOn)); panel.Children.Add(toggle);
            } else if (kind == "choice") {
                var choices = spec["choices"]!.AsArray().Select(x => x!.GetValue<string>()).ToArray();
                var combo = new ComboBox { Header = label, HorizontalAlignment = HorizontalAlignment.Stretch };
                foreach (var choice in choices) combo.Items.Add(SettingsStore.Text(choice == "all" ? "All agents" : choice));
                combo.SelectedIndex = key == "agentSource" ? Array.IndexOf(choices, settings.Values[key]!.GetValue<string>()) : (int)settings.Number(key);
                combo.SelectionChanged += (_, _) => { if (combo.SelectedIndex >= 0) Save(key, key == "agentSource" ? JsonValue.Create(choices[combo.SelectedIndex]) : JsonValue.Create((double)combo.SelectedIndex)); };
                panel.Children.Add(combo);
            } else if (kind == "color") {
                var c = settings.Values[key]!.AsArray();
                var picker = new ColorPicker { IsAlphaEnabled = false, Color = Color.FromArgb(255, (byte)(c[0]!.GetValue<double>() * 255), (byte)(c[1]!.GetValue<double>() * 255), (byte)(c[2]!.GetValue<double>() * 255)) };
                picker.ColorChanged += (_, e) => Save(key, new JsonArray(e.NewColor.R / 255d, e.NewColor.G / 255d, e.NewColor.B / 255d));
                panel.Children.Add(new Expander { Header = label, Content = picker, HorizontalAlignment = HorizontalAlignment.Stretch });
            } else {
                var value = new TextBlock { Text = label + " · " + settings.Number(key).ToString("0.##") };
                var min = spec["min"]!.GetValue<double>(); var max = spec["max"]!.GetValue<double>();
                var slider = new Slider { Minimum = min, Maximum = max, Value = settings.Number(key), StepFrequency = key == "artworkColors" ? 1 : (max - min) / 500 };
                Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(slider, label);
                slider.ValueChanged += (_, e) => { value.Text = label + " · " + e.NewValue.ToString("0.##"); Save(key, JsonValue.Create(e.NewValue)); };
                panel.Children.Add(value); panel.Children.Add(slider);
                if (key == "hue") panel.Children.Add(Rainbow());
            }
            content.Children.Add(border);
        }
        if (group == "Music") {
            var audio = new Button { Content = SettingsStore.Text("Activate audio") };
            audio.Click += (_, _) => { media.ArmAudio(); media.SetActive(!paused, settings); }; content.Children.Add(audio);
            var artwork = new Button { Content = SettingsStore.Text("Authorize open players") };
            artwork.Click += async (_, _) => await media.ConnectArtwork(); content.Children.Add(artwork);
        }
        if (group == "AI agents") {
            content.Children.Add(new TextBlock { Text = SettingsStore.Text("Connect each agent using the supplied hooks or API adapter."), TextWrapping = TextWrapping.Wrap });
            var export = new Button { Content = SettingsStore.Text("Open setup files") };
            export.Click += (_, _) => { try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("explorer.exe", Agents.Export()) { UseShellExecute = true }); } catch (Exception e) { ShowError(e.Message); } };
            content.Children.Add(export);
        }
        if (group == "General") {
            var pause = new Button { Content = SettingsStore.Text(paused ? "Resume animation" : "Pause animation") };
            pause.Click += (_, _) => { paused = !paused; pause.Content = SettingsStore.Text(paused ? "Resume animation" : "Pause animation"); Tick(); }; content.Children.Add(pause);
            var start = new Button { Content = SettingsStore.Text("Matriz · Animated wallpaper") };
            start.Click += async (_, _) => await StartWallpaper(); content.Children.Add(start);
            content.Children.Add(new TextBlock { Text = "Matriz · " + File.ReadAllText(Path.Combine(SettingsStore.Assets, "version.txt")), TextWrapping = TextWrapping.Wrap });

        }
    }
    private void Save(string key, JsonNode? value) { try { settings.Set(key, value); } catch (Exception error) { ShowError(error.Message); } }
    private static Rectangle Rainbow()
    {
        var brush = new LinearGradientBrush { StartPoint = new Windows.Foundation.Point(0, .5), EndPoint = new Windows.Foundation.Point(1, .5) };
        var colors = new[] { Color.FromArgb(255,255,0,0), Color.FromArgb(255,255,255,0), Color.FromArgb(255,0,255,0), Color.FromArgb(255,0,255,255), Color.FromArgb(255,0,0,255), Color.FromArgb(255,255,0,255), Color.FromArgb(255,255,0,0) };
        for (var i = 0; i < colors.Length; i++) brush.GradientStops.Add(new GradientStop { Color = colors[i], Offset = i / 6d });
        return new Rectangle { Height = 3, RadiusX = 1.5, RadiusY = 1.5, Fill = brush };
    }
}
