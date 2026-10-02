import AppKit
import CoreText

/// Only offer installed families that cover the Arabic alphabet and basic harakat.
/// This is a glyph-coverage check, not a claim that every font is Quran-reviewed.
enum ArabicFonts {
    static let defaultName = "Geeza Pro"
    static let quranName = "AmiriQuran-Regular"
    private static let registered: Void = {
        guard let url = Quran.resourceBundle.url(forResource: "AmiriQuran-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func displayName(_ name: String) -> String {
        name == quranName ? "Amiri Quran · Uthmani" : name
    }
    private static let required = CharacterSet(charactersIn: "ءآأإابتثجحخدذرزسشصضطظعغفقكلمنهويىةًٌٍَُِّْ")

    static let available: [String] = {
        _ = registered
        let installed = NSFontManager.shared.availableFontFamilies.filter { name in
            guard let font = NSFont(name: name, size: 30) else { return false }
            return required.isSubset(of: font.coveredCharacterSet)
        }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return NSFont(name: quranName, size: 30) != nil
            ? [quranName] + installed.filter { $0 != "Amiri Quran" && $0 != quranName }
            : installed
    }()

    static func resolvedName(_ name: String?) -> String {
        guard let name, available.contains(name) else { return defaultName }
        return name
    }

    static func font(name: String, size: Double) -> NSFont {
        _ = registered
        return NSFont(name: name, size: size)
            ?? NSFont(name: defaultName, size: size)
            ?? NSFont.systemFont(ofSize: size)
    }
}
