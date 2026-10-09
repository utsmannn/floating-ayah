import AppKit
import XCTest
@testable import FloatingAyah

final class TypographyTests: XCTestCase {
    func testMarkersKeepSourceRangesAndArabicNumerals() throws {
        let current = "ٱلْحَمْدُ لِلَّهِ"
        let document = LyricsDocument(current: current, previous: "بِسْمِ", next: "ٱلرَّحْمَٰنِ",
                                      currentNumber: 282, previousNumber: 281, nextNumber: 283)
        let source = document.text as NSString
        XCTAssertEqual(source.substring(with: document.currentRange), current)
        XCTAssertEqual(source.substring(with: try XCTUnwrap(document.currentMarkerRange)), "\u{00A0}﴿٢٨٢﴾")
        XCTAssertEqual(document.markerRanges.count, 3)
        XCTAssertFalse(document.text.contains("\n\n"))
        XCTAssertEqual(document.text.filter { $0 == "\n" }.count, 2)
        let lastWord = try XCTUnwrap(TimedAyah.wordRanges(in: current).last)
        XCTAssertEqual(source.substring(with: try XCTUnwrap(document.absoluteReadingRange(lastWord))), "لِلَّهِ")
        XCTAssertEqual(LyricsDocument.ayahMarker(1), "\u{00A0}﴿١﴾")
    }

    func testParagraphBoundaryHasSameBaselineGapAsWrappedLine() throws {
        for font in [ArabicFonts.defaultName, ArabicFonts.quranName] {
            let text = Array(repeating: "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ", count: 5).joined(separator: " ")
            let storage = NSTextStorage(attributedString: ArabicTypography.attributed(text + "\n" + text, size: 30, fontName: font))
            let manager = NSLayoutManager()
            manager.usesFontLeading = false
            let container = NSTextContainer(containerSize: NSSize(width: 280, height: 10000))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            storage.addLayoutManager(manager)
            manager.ensureLayout(for: container)
            var origins: [CGFloat] = []
            manager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)) { rect, _, _, _, _ in
                origins.append(rect.minY)
            }
            XCTAssertGreaterThan(origins.count, 4)
            for index in 1..<origins.count {
                XCTAssertEqual(origins[index] - origins[index - 1], ArabicTypography.lineHeight(size: 30), accuracy: 1)
            }
            let style = try XCTUnwrap(storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            XCTAssertEqual(style.lineSpacing, 0)
            XCTAssertEqual(style.paragraphSpacing, 0)
        }
    }

    func testCustomSpacingChangesWrapAndAyahBoundariesTogether() throws {
        let text = Array(repeating: "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ", count: 5).joined(separator: " ")
        for spacing in [0.0, 12.0, 24.0] {
            let styled = ArabicTypography.attributed(text + "\n" + text, size: 30,
                                                     fontName: ArabicFonts.quranName, spacing: spacing)
            let storage = NSTextStorage(attributedString: styled)
            let manager = NSLayoutManager()
            manager.usesFontLeading = false
            let container = NSTextContainer(containerSize: NSSize(width: 280, height: 10000))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            storage.addLayoutManager(manager)
            manager.ensureLayout(for: container)
            var previous: CGFloat?
            manager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)) { rect, _, _, _, _ in
                if let previous { XCTAssertEqual(rect.minY - previous, ArabicTypography.lineHeight(size: 30, spacing: spacing), accuracy: 1) }
                previous = rect.minY
            }
        }
        let compact = PanelLayout(text: text, fontSize: 30, availableHeight: 900, spacing: 0)
        let relaxed = PanelLayout(text: text, fontSize: 30, availableHeight: 900, spacing: 24)
        XCTAssertEqual(relaxed.viewportHeight - compact.viewportHeight, 72)
    }

    func testStyledNumbersDoNotBecomePointerTargets() throws {
        let scroll = LyricsScrollView(frame: NSRect(x: 0, y: 0, width: 364, height: 156))
        let view = ClickableAyahView()
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.heightTracksTextView = false
        scroll.documentView = view
        scroll.text = "ٱلْحَمْدُ لِلَّهِ"
        scroll.currentNumber = 2
        scroll.previousText = "بِسْمِ"
        scroll.previousNumber = 1
        scroll.readingRange = TimedAyah.wordRanges(in: scroll.text).last
        scroll.updateText()
        let document = try XCTUnwrap(scroll.renderedDocument)
        let marker = try XCTUnwrap(document.currentMarkerRange)
        let font = try XCTUnwrap(view.textStorage?.attribute(.font, at: marker.location, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(font.fontName, ArabicFonts.quranName)
        XCTAssertEqual(font.pointSize, 30, accuracy: 0.01)
        scroll.lyricAppearance.ayahNumberScale = 1.15
        scroll.updateText()
        let enlarged = try XCTUnwrap(view.textStorage?.attribute(.font, at: marker.location, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(enlarged.pointSize, 34.5, accuracy: 0.01)
        XCTAssertLessThan(NSMaxRange(try XCTUnwrap(scroll.highlightedWord)), NSMaxRange(document.currentRange) + 1)
        XCTAssertNil(view.layoutManager?.temporaryAttribute(.backgroundColor, atCharacterIndex: marker.location, effectiveRange: nil))
    }
}
