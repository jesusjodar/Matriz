import Foundation

// Codable wire shapes used by WallpaperExtensionKit; see ThirdPartyNotices.txt.
enum MatrizWallpaperCatalog {
    struct ID: Codable { var id: String }
    struct ChoiceID: Codable { var id: String; var descriptor: Descriptor }
    struct Descriptor: Codable { var provider: String; var identifier: String; var files: [URL]; var configuration: Data }
    enum Disposability: Codable { case none }
    enum Badge: Codable { case video }
    enum Thumbnail: Codable { case image(url: URL) }
    enum Refresh: Codable { case `default` }
    struct Choice: Codable {
        var id: ChoiceID; var provider: String; var identifier: String; var name: String
        var localizedDescription: String; var thumbnail: Thumbnail; var isDownloaded = true
        var options: [String] = []
    }
    struct Item: Codable {
        var id: ChoiceID; var localizedName: String; var thumbnail: Thumbnail; var choice: Choice
        var contentBadge = Badge.video; var showInTopLevel = true; var sortOrder = 0
        var disposability = Disposability.none
    }
    struct Group: Codable {
        var id = ID(id: "matriz"); var items: [Item]; var localizedName = "Matriz"
        var disposability = Disposability.none; var sortOrder = -100
        var sortID = ID(id: "com.apple.wallpaper.aerials"); var shouldHideItemLabels = false
    }
    struct ViewModel: Codable {
        var groups: [Group]; var refreshPolicy = Refresh.default; var isModificationDisabled = false
    }
    struct Models: Codable { var desktop: ViewModel; var screenSaver: ViewModel }

    static func models(bundle: Bundle = .main) -> AnyObject? {
        guard let url = bundle.url(forResource: "Matriz-thumbnail", withExtension: "png"),
              let realClass = objc_getClass("WallpaperSettingsViewModelsXPC") as? AnyClass else { return nil }
        let provider = bundle.bundleIdentifier ?? "com.matriz.wallpaper.extension"
        let id = ChoiceID(id: "matriz-live", descriptor: Descriptor(provider: provider, identifier: "matriz-live", files: [], configuration: Data()))
        let thumbnail = Thumbnail.image(url: url)
        let choice = Choice(id: id, provider: provider, identifier: "matriz-live", name: "Matriz",
            localizedDescription: "Matriz", thumbnail: thumbnail)
        let item = Item(id: id, localizedName: "Matriz", thumbnail: thumbnail, choice: choice)
        let model = ViewModel(groups: [Group(items: [item])])
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: MatrizWallpaperModels(value: Models(desktop: model, screenSaver: model)), requiringSecureCoding: false)
            let decoder = try NSKeyedUnarchiver(forReadingFrom: data)
            decoder.requiresSecureCoding = false
            decoder.decodingFailurePolicy = .setErrorAndReturn
            decoder.setClass(realClass, forClassName: "MatrizWallpaperModels")
            let result = decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
            decoder.finishDecoding()
            guard decoder.error == nil else { return nil }
            return result as AnyObject?
        } catch { NSLog("Matriz Wallpaper catalog: %@", error.localizedDescription); return nil }
    }
}

@objc(MatrizWallpaperModels)
final class MatrizWallpaperModels: NSObject, NSSecureCoding {
    static let supportsSecureCoding = true
    let value: MatrizWallpaperCatalog.Models
    init(value: MatrizWallpaperCatalog.Models) { self.value = value; super.init() }
    required init?(coder: NSCoder) { return nil }
    func encode(with coder: NSCoder) {
        do { try (coder as? NSKeyedArchiver)?.encodeEncodable(value, forKey: "WallpaperSettingsViewModels") }
        catch { NSLog("Matriz Wallpaper encode: %@", error.localizedDescription) }
    }
}
