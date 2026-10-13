import AppKit
import XCTest
@testable import FloatingAyah

final class LyricsTests: XCTestCase {
    func testTimedRangeFollowsAudioAndHoldsDuringSilence() {
        let text = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"
        let timing = TimedAyah(surah: 1, ayah: 1, segments: [[0, 1, 100, 500], [1, 2, 700, 1100], [2, 4, 1200, 2400]])
        XCTAssertNil(timing.readingRange(at: 0, in: text))
        let first = timing.readingRange(at: 0.2, in: text)
        XCTAssertEqual((text as NSString).substring(with: first ?? NSRange()), "بِسْمِ")
        XCTAssertEqual(timing.readingRange(at: 0.6, in: text), first)
        let last = timing.readingRange(at: 1.5, in: text)
        XCTAssertEqual((text as NSString).substring(with: last ?? NSRange()), "ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
    }

    func testRepeatedPhraseMovesBackwardsWithoutEstimatingProgress() {
        let timing = TimedAyah(surah: 1, ayah: 1, segments: [[0, 1, 0, 200], [1, 2, 200, 400], [0, 1, 600, 800]])
        let text = "بِسْمِ ٱللَّهِ"
        XCTAssertEqual(timing.readingRange(at: 0.7, in: text), timing.readingRange(at: 0.1, in: text))
        XCTAssertNotEqual(timing.readingRange(at: 0.3, in: text), timing.readingRange(at: 0.7, in: text))
    }

    func testInvalidTimingDoesNotScrollToWrongText() {
        let timing = TimedAyah(surah: 1, ayah: 1, segments: [[99, 100, 0, 100]])
        XCTAssertNil(timing.readingRange(at: 0.1, in: "بِسْمِ ٱللَّهِ"))
    }

    func testBundledTimingsMatchWaqafAndBasmalahIndexing() throws {
        let quran = try Quran.load()
        let timings = try WordTimings.load()
        XCTAssertEqual(timings.ayahs.count, 6236)
        let longText = quran.surahs[1].ayahs[281].text
        XCTAssertEqual(TimedAyah.wordRanges(in: longText).count, 128)
        let range = try XCTUnwrap(timings.range(surah: 2, ayah: 282, seconds: 144, text: longText))
        // The bundled Uthmani edition includes U+06ED after the final tanween.
        XCTAssertEqual((longText as NSString).substring(with: range), "عَلِيمٌ\u{06ED}")
        let opening = quran.surahs[1].ayahs[0].text
        let openingRange = try XCTUnwrap(timings.range(surah: 2, ayah: 1, seconds: 1, text: opening))
        XCTAssertEqual((opening as NSString).substring(with: openingRange), "الٓمٓ")
        var compatible = 0
        for surah in quran.surahs {
            for ayah in surah.ayahs {
                if timings.range(surah: surah.number, ayah: ayah.number, seconds: 10_000, text: ayah.text) != nil {
                    compatible += 1
                }
            }
        }
        XCTAssertEqual(compatible, 6233) // Three upstream token-count mismatches safely omit word following.
    }

    func testLongAyahUsesCompactThreeLineViewport() throws {
        let quran = try Quran.load()
        let layout = PanelLayout(text: quran.surahs[1].ayahs[281].text, fontSize: 30, availableHeight: 900)
        XCTAssertEqual(layout.viewportHeight, ArabicTypography.lineHeight(size: 30) * 3)
        XCTAssertLessThan(layout.height, 450)
        XCTAssertEqual(PanelLayout.width, 420)
        XCTAssertTrue(layout.needsScroll)
    }

    func testNativeTextStartsAtBeginningAndScrollsToReadingLine() {
        let text = Array(repeating: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ", count: 30).joined(separator: " ")
        let scroll = LyricsScrollView(frame: NSRect(x: 0, y: 0, width: 364, height: 144))
        let view = ClickableAyahView()
        view.isVerticallyResizable = false
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.heightTracksTextView = false
        scroll.documentView = view
        scroll.text = text
        scroll.reduceMotion = true
        scroll.updateText()
        let initialOffset = scroll.contentView.bounds.minY
        scroll.readingRange = TimedAyah.wordRanges(in: text).last
        scroll.updateText()
        XCTAssertGreaterThan(scroll.contentView.bounds.minY, initialOffset)
        scroll.text = "بِسْمِ ٱللَّهِ"
        scroll.readingRange = nil
        scroll.updateText()
        XCTAssertLessThan(scroll.contentView.bounds.minY, 20)
    }
}
