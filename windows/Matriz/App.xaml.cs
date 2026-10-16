using Microsoft.UI.Xaml;

namespace Matriz;

public partial class App : Application
{
    private SettingsWindow? window;
    public App() { InitializeComponent(); }
    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        window = new SettingsWindow();
        window.Activate();
    }
}
