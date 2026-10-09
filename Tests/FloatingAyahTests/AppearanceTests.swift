import AppKit
import XCTest
@testable import FloatingAyah

final class AppearanceTests: XCTestCase {
    func testBundledQuranFontIsRegistered() throws {
        XCTAssertTrue(ArabicFonts.available.contains(ArabicFonts.quranName))
        XCTAssertNotNil(NSFont(name: ArabicFonts.quranName, size: 30))
        XCTAssertEqual(ArabicFonts.resolvedName(ArabicFonts.quranName), ArabicFonts.quranName)
    }

    @MainActor
    func testAppearancePersistsAndValidatesWidthAndShadow() throws {
        let suite = "FloatingAyahAppearance.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let quran = try Quran.load()
        let store = PlayerStore(quran: quran, defaults: defaults)
        store.appearance.textColor = LyricColor(red: 0.9, green: 0.8, blue: 0.3)
        store.appearance.shadowColor = LyricColor(red: 0.1, green: 0.2, blue: 0.3)
        store.appearance.shadowDepth = 8
        store.appearance.shadowBlur = 12
        store.appearance.panelWidth = 640
        store.appearance.lineSpacing = 14
        store.appearance.ayahNumberScale = 1.1
        store.appearance.continuousText = true
        store.appearance.backgroundColor = LyricColor(red: 0.1, green: 0.3, blue: 0.5)
        store.appearance.backgroundOpacity = 0.4
        store.fontSize = 38
        let restored = PlayerStore(quran: quran, defaults: defaults)
        XCTAssertEqual(restored.appearance, store.appearance)
        XCTAssertEqual(restored.fontSize, 38)
        XCTAssertEqual(restored.appearance.shadow?.shadowOffset.height, -8)
        restored.appearance.shadowEnabled = false
        XCTAssertNil(restored.appearance.shadow)
        var invalid = LyricAppearance()
        invalid.panelWidth = 9999
        invalid.shadowDepth = -4
        invalid.shadowOpacity = 9
        invalid.backgroundOpacity = 7
        invalid.save(to: defaults)
        let valid = LyricAppearance.load(from: defaults)
        XCTAssertEqual(valid.panelWidth, 800)
        XCTAssertEqual(valid.shadowDepth, 0)
        XCTAssertEqual(valid.shadowOpacity, 1)
        XCTAssertEqual(valid.backgroundOpacity, 1)
    }

    func testLegacyAppearanceRetainsSettingsAndAddsTypographyDefaults() throws {
        let suite = "FloatingAyahMigration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(LyricAppearance())) as? [String: Any])
        old.removeValue(forKey: "lineSpacing")
        old.removeValue(forKey: "ayahNumberScale")
        old.removeValue(forKey: "continuousText")
        old.removeValue(forKey: "backgroundColor")
        old.removeValue(forKey: "backgroundOpacity")
        old["panelWidth"] = 630
        old["shadowDepth"] = 9
        defaults.set(try JSONSerialization.data(withJSONObject: old), forKey: "lyricAppearance")
        let restored = LyricAppearance.load(from: defaults)
        XCTAssertEqual(restored.panelWidth, 630)
        XCTAssertEqual(restored.shadowDepth, 9)
        XCTAssertEqual(restored.lineSpacing, 6)
        XCTAssertEqual(restored.ayahNumberScale, 1)
        XCTAssertFalse(restored.continuousText)
        XCTAssertEqual(restored.backgroundOpacity, 0)
        XCTAssertEqual(restored.backgroundColor, .black)
        var invalid = restored
        invalid.lineSpacing = 100
        invalid.ayahNumberScale = 0.1
        invalid.save(to: defaults)
        XCTAssertEqual(LyricAppearance.load(from: defaults).lineSpacing, 24)
        XCTAssertEqual(LyricAppearance.load(from: defaults).ayahNumberScale, 0.6)
    }

    func testWidthReflowsQuranWithoutChangingFontSize() throws {
        let text = try Quran.load().surahs[1].ayahs[281].text
        let narrow = PanelLayout(text: text, fontSize: 30, availableHeight: 900,
                                 fontName: ArabicFonts.quranName, width: 280)
        let wide = PanelLayout(text: text, fontSize: 30, availableHeight: 900,
                               fontName: ArabicFonts.quranName, width: 800)
        XCTAssertEqual(narrow.contentWidth, 280)
        XCTAssertEqual(wide.contentWidth, 800)
        XCTAssertGreaterThan(narrow.textHeight, wide.textHeight)
        XCTAssertEqual(narrow.viewportHeight, wide.viewportHeight)
    }

    func testNeighborDocumentPreservesArabicAndOffsetsTimings() throws {
        let document = LyricsDocument(current: "ٱلْحَمْدُ لِلَّهِ", previous: "بِسْمِ ٱللَّهِ", next: "ٱلرَّحْمَٰنِ")
        let source = document.text as NSString
        XCTAssertEqual(source.substring(with: document.currentRange), "ٱلْحَمْدُ لِلَّهِ")
        XCTAssertEqual(source.substring(with: try XCTUnwrap(document.previousRange)), "بِسْمِ ٱللَّهِ")
        XCTAssertEqual(source.substring(with: try XCTUnwrap(document.nextRange)), "ٱلرَّحْمَٰنِ")
        let relative = try XCTUnwrap(TimedAyah.wordRanges(in: "ٱلْحَمْدُ لِلَّهِ").last)
        let absolute = try XCTUnwrap(document.absoluteReadingRange(relative))
        XCTAssertEqual(source.substring(with: absolute), "لِلَّهِ")
        XCTAssertNil(document.absoluteReadingRange(NSRange(location: 999, length: 1)))
        let boundary = LyricsDocument(current: "بِسْمِ", previous: nil, next: nil)
        XCTAssertEqual(boundary.currentRange.location, 0)
    }

    func testNativeNeighborsAreDimAndCurrentLineIsCentered() throws {
        let scroll = LyricsScrollView(frame: NSRect(x: 0, y: 0, width: 364, height: 144))
        let view = ClickableAyahView()
        view.isVerticallyResizable = false
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.heightTracksTextView = false
        scroll.documentView = view
        scroll.text = "ٱلْحَمْدُ لِلَّهِ"
        scroll.previousText = "بِسْمِ ٱللَّهِ"
        scroll.nextText = "ٱلرَّحْمَٰنِ"
        scroll.lyricAppearance.shadowEnabled = false
        scroll.updateText()
        let document = try XCTUnwrap(scroll.renderedDocument)
        let storage = try XCTUnwrap(view.textStorage)
        let previous = try XCTUnwrap(document.previousRange)
        let dim = try XCTUnwrap(storage.attribute(.foregroundColor, at: previous.location, effectiveRange: nil) as? NSColor)
        XCTAssertEqual(dim.alphaComponent, 0.3, accuracy: 0.01)
        XCTAssertNil(storage.attribute(.shadow, at: document.currentRange.location, effectiveRange: nil))
        XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0)
        let currentWord = TimedAyah.wordRanges(in: scroll.text).first
        scroll.readingRange = currentWord
        scroll.updateText()
        XCTAssertNotNil(view.layoutManager?.temporaryAttribute(.foregroundColor,
                                                               atCharacterIndex: document.currentRange.location,
                                                               effectiveRange: nil))
    }
}
