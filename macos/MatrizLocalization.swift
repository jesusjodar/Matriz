import Foundation

private final class MatrizBundleAnchor: NSObject {}

enum MatrizI18n {
    // The saver runs inside another app: resolve resources from our own bundle.
    static let bundle = Bundle(for: MatrizBundleAnchor.self)
    static var isRightToLeft: Bool {
        ["ar", "he"].contains(bundle.preferredLocalizations.first ?? "en")
    }
    static func text(_ key: String, in bundle: Bundle = MatrizI18n.bundle) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
func L(_ key: String) -> String { MatrizI18n.text(key) }
func LF(_ key: String, _ values: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: values)
}
