import AppKit
import CoreGraphics
import SwiftUI
import XCTest
@testable import FloatingAyah

final class PanelInteractionTests: XCTestCase {
    func testInlineBasmalahAndAyahsPreserveMarkersAndTimedRanges() throws {
        let quran = try Quran.load()
        let position = AyahPosition(surah: 1, ayah: 0)
        let opening = try XCTUnwrap(quran.basmalah(at: position))
        let current = quran.text(at: position)
        let next = quran.text(at: AyahPosition(surah: 1, ayah: 1))
        let document = LyricsDocument(current: current, previous: opening, next: next,
                                      currentNumber: 1, nextNumber: 2, continuousText: true)
        XCTAssertFalse(document.text.contains("\n"))
        XCTAssertEqual(document.text, opening + " " + current + LyricsDocument.ayahMarker(1)
                       + " " + next + LyricsDocument.ayahMarker(2))
        let source = document.text as NSString
        XCTAssertEqual(source.substring(with: try XCTUnwrap(document.previousRange)), opening)
        XCTAssertEqual(source.substring(with: document.currentRange), current)
        XCTAssertEqual(source.substring(with: try XCTUnwrap(document.nextRange)), next)
        let word = try XCTUnwrap(TimedAyah.wordRanges(in: current).first)
        XCTAssertEqual(source.substring(with: try XCTUnwrap(document.absoluteReadingRange(word))),
                       (current as NSString).substring(with: word))
        XCTAssertEqual(document.markerRanges.count, 2) // Basmalah remains unnumbered.
    }

    @MainActor
    func testContinuousSurahTextIsIdenticalForEveryAyahSoNothingReflows() throws {
        let suite = "FloatingAyahStable.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PlayerStore(quran: try Quran.load(), defaults: defaults)
        store.select(surah: 1, ayah: 0)
        var texts = Set<String>()
        var reference: String?
        for ayah in [0, 1, 40, 285] {
            store.select(surah: 1, ayah: ayah)
            let context = try XCTUnwrap(store.continuousContext)
            let document = LyricsDocument(before: context.before, current: store.displayText,
                                          currentNumber: store.displayNumber, after: context.after)
            texts.insert(document.text)
            if let reference, reference != document.text {
                let expected = Array(reference.unicodeScalars)
                let actual = Array(document.text.unicodeScalars)
                let offset = zip(expected, actual).enumerated().first { $0.element.0 != $0.element.1 }?.offset
                XCTFail("ayah \(ayah) differs at \(offset ?? -1); lengths \(expected.count) vs \(actual.count)")
            }
            reference = reference ?? document.text
            XCTAssertEqual((document.text as NSString).substring(with: document.currentRange), store.displayText)
        }
        XCTAssertEqual(texts.count, 1)
        // The opening basmalah owns the first line; ayah 1 starts the next one.
        let text = try XCTUnwrap(texts.first)
        let opening = try XCTUnwrap(store.quran.basmalah(at: AyahPosition(surah: 1, ayah: 0)))
        XCTAssertTrue(text.hasPrefix(opening + "\n"))
        XCTAssertEqual(text.filter { $0 == "\n" }.count, 1)
        // Al-Fatihah (basmalah is ayah 1) and At-Tawbah (none) have no forced line break.
        for surah in [0, 8] {
            store.select(surah: surah, ayah: 2)
            let context = try XCTUnwrap(store.continuousContext)
            let flowing = LyricsDocument(before: context.before, current: store.displayText,
                                         currentNumber: store.displayNumber, after: context.after).text
            XCTAssertFalse(flowing.contains("\n"), "surah index \(surah)")
        }
    }

    func testPlayingAyahBeforeFirstTimedWordHighlightsOnlyItsFirstLine() throws {
        let (scroll, view) = makeLyrics()
        scroll.lyricAppearance.continuousText = true
        scroll.isPlaying = true
        let phrase = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ "
        scroll.surahBefore = [LyricSegment(text: String(repeating: phrase, count: 7), number: 1)]
        scroll.surahAfter = []
        scroll.text = String(repeating: phrase, count: 14)
        scroll.currentNumber = 2
        scroll.readingRange = nil // New ayah: no timed word yet.
        scroll.updateText()
        let document = try XCTUnwrap(scroll.renderedDocument)
        let manager = try XCTUnwrap(view.layoutManager)
        func alpha(at index: Int) -> CGFloat? {
            (manager.temporaryAttribute(.foregroundColor, atCharacterIndex: index, effectiveRange: nil) as? NSColor)?.alphaComponent
        }
        let first = document.currentRange.location
        let last = NSMaxRange(document.currentRange) - 1
        XCTAssertEqual(try XCTUnwrap(alpha(at: first)), 1, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(alpha(at: last)), 0.55, accuracy: 0.01)
        // The first timed word then stays on that same line.
        scroll.readingRange = TimedAyah.wordRanges(in: scroll.text).first
        scroll.updateText()
        XCTAssertEqual(try XCTUnwrap(alpha(at: first)), 1, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(alpha(at: last)), 0.55, accuracy: 0.01)
    }

    func testWordMarkerFollowsEveryWordAcrossLineBreaksInContinuousMode() throws {
        let (scroll, view) = makeLyrics()
        scroll.lyricAppearance.continuousText = true
        scroll.lyricAppearance.backgroundOpacity = 0.5
        scroll.isPlaying = true
        let words = TimedAyah.wordRanges(in: scroll.text)
        let manager = try XCTUnwrap(view.layoutManager)
        var previous: NSRange?
        var lineChanges = 0
        var lastLineY: CGFloat?
        for word in words {
            scroll.readingRange = word
            scroll.updateText()
            let document = try XCTUnwrap(scroll.renderedDocument)
            let expected = try XCTUnwrap(document.absoluteReadingRange(word))
            XCTAssertEqual(scroll.highlightedWord, expected, "marker must land on the word being read")
            XCTAssertNotNil(manager.temporaryAttribute(.underlineStyle, atCharacterIndex: expected.location, effectiveRange: nil))
            if let previous, previous != expected {
                XCTAssertNil(manager.temporaryAttribute(.underlineStyle, atCharacterIndex: previous.location, effectiveRange: nil),
                             "the previous word must lose its marker")
            }
            let glyph = manager.glyphIndexForCharacter(at: expected.location)
            let lineY = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
            if let lastLineY, lastLineY != lineY { lineChanges += 1 }
            lastLineY = lineY
            previous = expected
        }
        XCTAssertGreaterThan(lineChanges, 3, "the sample must cross several line breaks")
    }

    func testInlineToggleRebuildsTextAndKeepsAutomaticFollowing() throws {
        let (scroll, view) = makeLyrics()
        scroll.previousText = "بِسْمِ ٱللَّهِ"
        scroll.nextText = "ٱلرَّحْمَٰنِ"
        scroll.updateText()
        XCTAssertTrue(view.string.contains("\n"))
        scroll.lyricAppearance.continuousText = true
        scroll.updateText()
        XCTAssertFalse(view.string.contains("\n"))
        let before = scroll.contentView.bounds.minY
        scroll.readingRange = TimedAyah.wordRanges(in: scroll.text).last
        scroll.updateText()
        XCTAssertGreaterThan(scroll.contentView.bounds.minY, before)
        let word = try XCTUnwrap(scroll.highlightedWord)
        XCTAssertEqual((view.string as NSString).substring(with: word), "ٱلرَّحِيمِ")
        scroll.lyricAppearance.continuousText = false
        scroll.updateText()
        XCTAssertTrue(view.string.contains("\n"))
    }

    func testContinuousTextIsJustifiedAndNormalTextStaysRightAligned() throws {
        let (scroll, view) = makeLyrics()
        scroll.previousText = "بِسْمِ ٱللَّهِ"
        scroll.nextText = "ٱلرَّحْمَٰنِ"
        scroll.updateText()
        func alignment() throws -> NSTextAlignment {
            let style = try XCTUnwrap(view.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            return style.alignment
        }
        XCTAssertEqual(try alignment(), .right)
        scroll.lyricAppearance.continuousText = true
        scroll.updateText()
        XCTAssertEqual(try alignment(), .justified)
    }

    func testLineBackgroundCoversOnlyTheActiveLineAndMovesWithIt() throws {
        let (scroll, view) = makeLyrics()
        scroll.lyricAppearance.backgroundColor = LyricColor(red: 0.2, green: 0.4, blue: 0.6)
        scroll.lyricAppearance.backgroundOpacity = 0.5
        let words = TimedAyah.wordRanges(in: scroll.text)
        scroll.readingRange = words[0]
        scroll.updateText()
        let manager = try XCTUnwrap(view.layoutManager)
        let document = try XCTUnwrap(scroll.renderedDocument)
        let first = try XCTUnwrap(document.absoluteReadingRange(words[0]))
        func background(at index: Int) -> NSColor? {
            manager.temporaryAttribute(.backgroundColor, atCharacterIndex: index, effectiveRange: nil) as? NSColor
        }
        // Characters on the active line (not the word marker) carry the configured color.
        let lineEnd = first.location + first.length + 12
        let onLine = try XCTUnwrap(background(at: min(lineEnd, document.currentRange.length)))
        XCTAssertEqual(onLine.alphaComponent, 0.5, accuracy: 0.01)
        // The previous/next ayahs and unread lines have no line background.
        scroll.readingRange = words[words.count - 1]
        scroll.updateText()
        XCTAssertNil(background(at: first.location + 30))
        let last = try XCTUnwrap(scroll.renderedDocument?.absoluteReadingRange(words[words.count - 1]))
        XCTAssertNotNil(background(at: last.location))
        scroll.lyricAppearance.backgroundOpacity = 0
        scroll.updateText()
        scroll.readingRange = words[0]
        scroll.updateText()
        XCTAssertNil(background(at: min(lineEnd, document.currentRange.length)))
    }

    func testWheelCannotMoveLyricsButAutomaticFollowerStillCan() throws {
        let (scroll, view) = makeLyrics()
        scroll.updateText()
        let before = scroll.contentView.bounds.origin
        let cgEvent = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                          wheelCount: 1, wheel1: -120, wheel2: 0, wheel3: 0))
        let event = try XCTUnwrap(NSEvent(cgEvent: cgEvent))
        scroll.scrollWheel(with: event)
        view.scrollWheel(with: event) // Text descendant forwards to the scroll view.
        XCTAssertEqual(scroll.contentView.bounds.origin, before)
        scroll.readingRange = TimedAyah.wordRanges(in: scroll.text).last
        scroll.updateText()
        XCTAssertGreaterThan(scroll.contentView.bounds.minY, before.y)
    }

    func testPanelUsesLyricBoundsWithoutReservedChromeAtAllFontSizes() {
        for size in [22.0, 30.0, 42.0] {
            let layout = PanelLayout(text: "بِسْمِ ٱللَّهِ", fontSize: size, availableHeight: 900)
            XCTAssertEqual(layout.height, ArabicTypography.lineHeight(size: size) * 3)
            XCTAssertEqual(layout.height, layout.viewportHeight)
            XCTAssertEqual(layout.contentWidth, layout.panelWidth)
        }
        XCTAssertEqual(PanelLayout.chromeHeight, 0)
    }

    @MainActor
    func testHostingContainsClickableTextAndAncestorDragRecognizer() throws {
        let suite = "FloatingAyahPanel.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PlayerStore(quran: try Quran.load(), defaults: defaults)
        let controller = PanelController(store: store)
        let root = try XCTUnwrap(controller.panel.contentView)
        root.layoutSubtreeIfNeeded()
        func findText(in view: NSView) -> ClickableAyahView? {
            if let text = view as? ClickableAyahView { return text }
            return view.subviews.lazy.compactMap { findText(in: $0) }.first
        }
        let text = try XCTUnwrap(findText(in: root))
        XCTAssertFalse(text.isSelectable)
        let drag = try XCTUnwrap(root.gestureRecognizers.first as? NSPanGestureRecognizer)
        XCTAssertTrue(drag.delaysPrimaryMouseButtonEvents)
        XCTAssertEqual(drag.buttonMask, 1)
        XCTAssertEqual(controller.panel.frame.height, ArabicTypography.lineHeight(size: store.fontSize) * 3)
    }

    private func makeLyrics() -> (LyricsScrollView, ClickableAyahView) {
        let scroll = LyricsScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 159))
        let view = ClickableAyahView()
        view.isSelectable = false
        view.isVerticallyResizable = false
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.heightTracksTextView = false
        scroll.documentView = view
        scroll.text = Array(repeating: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ", count: 30).joined(separator: " ")
        scroll.reduceMotion = true
        return (scroll, view)
    }
}
