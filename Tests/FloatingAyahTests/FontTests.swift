import AppKit
import XCTest
@testable import FloatingAyah

final class FontTests: XCTestCase {
    func testAvailableFontsAndFallback() {
        XCTAssertFalse(ArabicFonts.available.isEmpty)
        XCTAssertTrue(ArabicFonts.available.contains(ArabicFonts.defaultName))
        XCTAssertEqual(ArabicFonts.resolvedName("missing-font-for-test"), ArabicFonts.defaultName)
        for name in ArabicFonts.available {
            XCTAssertNotNil(NSFont(name: name, size: 30))
        }
    }

    @MainActor
    func testFontPreferencePersistsAndMeasurementUsesSelectedFont() throws {
        let suite = "FloatingAyahFontTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("missing-font-for-test", forKey: "fontName")
        let quran = try Quran.load()
        let store = PlayerStore(quran: quran, defaults: defaults)
        XCTAssertEqual(store.fontName, ArabicFonts.defaultName)
        let name = try XCTUnwrap(ArabicFonts.available.first(where: { $0 != ArabicFonts.defaultName }))
        store.fontName = name
        let restored = PlayerStore(quran: quran, defaults: defaults)
        XCTAssertEqual(restored.fontName, name)
        let styled = ArabicTypography.attributed(store.ayah.text, size: 30, fontName: name)
        let font = try XCTUnwrap(styled.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(font.fontName, ArabicFonts.font(name: name, size: 30).fontName)
        let layout = PanelLayout(text: quran.surahs[1].ayahs[281].text, fontSize: 30,
                                 availableHeight: 900, fontName: name)
        XCTAssertEqual(layout.textHeight, ArabicTypography.height(for: quran.surahs[1].ayahs[281].text,
                                                                 size: 30, width: 364, fontName: name))
        XCTAssertEqual(PanelLayout.width, 420)
    }
}
