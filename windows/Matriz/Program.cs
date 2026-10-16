using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;

namespace Matriz;

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        if (Agents.HandleCLI(args) is int result) return result;
        if (args.Contains("--self-test")) return SelfTest.Run();
        using var mutex = new Mutex(true, @"Local\Matriz.WinUI", out var first);
        if (!first) { Desktop.ShowSettings(); return 0; }
        Environment.SetEnvironmentVariable("WEBVIEW2_USER_DATA_FOLDER", Path.Combine(SettingsStore.Directory, "WebView2"));
        WinRT.ComWrappersSupport.InitializeComWrappers();
        Application.Start(parameters => {
            SynchronizationContext.SetSynchronizationContext(new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread()));
            _ = new App();
        });
        return 0;
    }
}
