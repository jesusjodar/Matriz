# Matriz for Windows

Desktop app with native WinUI 3 settings and a WebGL2 background hosted in WebView2. It shares the shader, visual settings and palettes with macOS and the web component; music and agent integrations belong only to the desktop apps.

## Installation

1. Download the **x64** ZIP for Intel/AMD or **ARM64** for Windows on ARM and check its SHA-256 with `Get-FileHash .\Matriz-Windows-x64.zip -Algorithm SHA256`.
2. Extract the **entire** folder to a stable location, such as `%LOCALAPPDATA%\Programs\Matriz`. Do not run the app inside the ZIP or copy only the `.exe`.
3. Open `Matriz.exe`. Requires Windows 10 1809 or later, Explorer and [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/). .NET and Windows App SDK are included.

This is a portable app without a commercial signature. Windows may show SmartScreen; review the file's source before allowing it to run. No administrator privileges are required. Close the app before replacing its files during updates; keep `%LOCALAPPDATA%\Matriz` to preserve settings.

## Settings and integrations

The panel uses top navigation, WinUI 3 controls, cards, color pickers and a hue strip. Preferences are saved atomically in `%LOCALAPPDATA%\Matriz\settings.json`, separately from Mac preferences.

- **Music:** enable WASAPI loopback capture under Music. It analyzes the default output without a microphone, recording or transmission. For artwork, authorize access to media sessions: the player must publish its artwork through Windows media controls. Images are processed in memory and never saved.
- **Agents:** enable the option and press **Open setup files**. This exports the same connectors as the [agent guide](../integrations/README.md), with your executable's path and a local PowerShell hook adapter. Add them to your existing configuration without replacing other hooks. They are not installed automatically and do not modify agents.
- **Generic state:** any agent can run `Matriz.exe --agent-event generic running my-session`. Valid states are `idle`, `running`, `input`, `permission`, `error` and `completed`. Messages, filenames and task content are not saved. Sessions are identified through SHA-256 and events expire.
- **Pause:** animation is suspended when locking, using a remote session or detecting a full-screen app. It respects the system's Reduce Motion setting and lowers quality in battery saver mode.

Closing the panel quits Matriz and removes the background. It does not start automatically with Windows. Errors inserting the background or loading WebView2 appear in the panel; the General tab provides a retry button.

## Compatibility and limitations

The background is inserted behind icons through Explorer's WorkerW container. **WorkerW is undocumented Explorer behavior**: a Windows update or alternative desktop may prevent it from working. It does not change the wallpaper saved by Windows. This version spans the entire virtual desktop; all displays share one composition.

No `.scr` screensaver or animated Windows lock screen is included. The macOS Wallpaper extension is Apple-specific and is not presented as an equivalent Windows feature. Audio and artwork need verification with your devices and players; the executable includes `--self-test` to validate settings, persistence, connectors and assets without changing your configuration.

## Build

On Windows, with Node 22 and Visual Studio with MSBuild, Windows SDK and WinUI tools:

```powershell
npm ci
npm run windows:prepare
msbuild windows/Matriz/Matriz.csproj /restore /t:Publish /p:Configuration=Release /p:Platform=x64 /p:RuntimeIdentifier=win-x64 /p:PublishDir="$PWD/publish/win-x64/"
```

For ARM64, replace `x64` with `ARM64` and `win-x64` with `win-arm64`. CI builds both architectures. See the [multiplatform workflow](https://github.com/jesusjodar/Matriz/actions/workflows/multiplatform.yml).
