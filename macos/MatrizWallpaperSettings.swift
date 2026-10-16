import Foundation

// The app can publish its visual settings into its sandboxed wallpaper extension's Documents.
enum MatrizWallpaperSettings {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/com.matriz.wallpaper.extension/Data/Documents")
    }
    static func publish(_ settings: MatrizSettings) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: settings.values, format: .binary, options: 0)
            try data.write(to: directory.appendingPathComponent("Matriz-settings.plist"), options: .atomic)
        } catch { NSLog("Matriz wallpaper settings: %@", error.localizedDescription) }
    }
}
