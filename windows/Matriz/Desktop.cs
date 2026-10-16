using System.Runtime.InteropServices;
using Microsoft.UI.Xaml;

namespace Matriz;

internal static class Desktop
{
    public delegate bool EnumCallback(nint window, nint parameter);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct Power { public byte AC, Battery, Percent, Saver; public uint Life, FullLife; }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern nint FindWindow(string? name, string? title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern nint FindWindowEx(nint parent, nint after, string? name, string? title);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, nint parameter);
    [DllImport("user32.dll", SetLastError = true)] private static extern nint SetParent(nint child, nint parent);
    [DllImport("user32.dll")] private static extern nint GetParent(nint child);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern nint SendMessageTimeout(nint hwnd, uint message, nint w, nint l, uint flags, uint timeout, out nint result);
    [DllImport("user32.dll")] private static extern nint GetWindowLongPtrW(nint hwnd, int index);
    [DllImport("user32.dll")] private static extern nint SetWindowLongPtrW(nint hwnd, int index, nint value);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(nint hwnd, nint after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] private static extern int MapWindowPoints(nint from, nint to, ref Point point, uint count);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] private static extern nint GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool GetWindowRect(nint hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool IsWindow(nint hwnd);
    [DllImport("user32.dll")] private static extern bool ShowWindow(nint hwnd, int command);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(nint hwnd);
    [DllImport("kernel32.dll")] private static extern bool GetSystemPowerStatus(out Power power);
    [DllImport("user32.dll")] private static extern nint OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll")] private static extern bool CloseDesktop(nint desktop);

    public static (int X, int Y, int Width, int Height) Bounds => (GetSystemMetrics(76), GetSystemMetrics(77), Math.Max(1, GetSystemMetrics(78)), Math.Max(1, GetSystemMetrics(79)));
    public static void ShowSettings() { var handle = FindWindow(null, "Matriz"); if (handle != 0) { ShowWindow(handle, 9); SetForegroundWindow(handle); } }
    public static bool BatterySaver => GetSystemPowerStatus(out var power) && power.Saver != 0;
    public static bool Remote => GetSystemMetrics(0x1000) != 0;
    public static bool SessionVisible { get { var desktop = OpenInputDesktop(0, false, 1); if (desktop == 0) return false; CloseDesktop(desktop); return true; } }

    public static nint Attach(Window window)
    {
        var progman = FindWindow("Progman", null);
        if (progman == 0) throw new InvalidOperationException("Explorer desktop is not available.");
        // shortcut: Explorer's WorkerW contract is undocumented; recheck it after shell updates.
        SendMessageTimeout(progman, 0x052C, 0, 0, 2, 1000, out _);
        nint worker = 0;
        EnumWindows((top, _) => {
            if (FindWindowEx(top, 0, "SHELLDLL_DefView", null) != 0) worker = FindWindowEx(0, top, "WorkerW", null);
            return worker == 0;
        }, 0);
        if (worker == 0) throw new InvalidOperationException("No compatible Explorer wallpaper surface was found.");
        var handle = WinRT.Interop.WindowNative.GetWindowHandle(window);
        var style = GetWindowLongPtrW(handle, -16).ToInt64();
        SetWindowLongPtrW(handle, -16, (nint)((style & ~0x80CF0000L) | 0x50000000L));
        SetWindowLongPtrW(handle, -20, (nint)(GetWindowLongPtrW(handle, -20).ToInt64() | 0x08000080L));
        SetParent(handle, worker);
        if (GetParent(handle) != worker) throw new InvalidOperationException("Windows rejected wallpaper attachment.");
        Resize(handle, worker);
        return worker;
    }
    public static void Resize(nint handle, nint worker)
    {
        var bounds = Bounds; var point = new Point { X = bounds.X, Y = bounds.Y };
        MapWindowPoints(0, worker, ref point, 1);
        if (!SetWindowPos(handle, (nint)1, point.X, point.Y, bounds.Width, bounds.Height, 0x0070)) throw new InvalidOperationException("Could not size the wallpaper.");
    }
    public static bool FullscreenOther(nint settings, nint wallpaper)
    {
        var foreground = GetForegroundWindow();
        if (foreground == 0 || foreground == settings || foreground == wallpaper || !GetWindowRect(foreground, out var rect)) return false;
        var shell = FindWindow("Progman", null);
        if (foreground == shell || FindWindowEx(foreground, 0, "SHELLDLL_DefView", null) != 0) return false;
        return rect.Right - rect.Left >= GetSystemMetrics(0) && rect.Bottom - rect.Top >= GetSystemMetrics(1);
    }
}
