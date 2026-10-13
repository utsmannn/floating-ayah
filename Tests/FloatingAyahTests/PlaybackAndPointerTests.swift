import AppKit
import XCTest
@testable import FloatingAyah

final class PlaybackAndPointerTests: XCTestCase {
    @MainActor
    func testPlaybackLabelsAndSizesAreEnglish() throws {
        let suite = "FloatingAyahEnglish.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PlayerStore(quran: try Quran.load(), defaults: defaults)
        XCTAssertEqual(store.actionLabel, "Play")
        XCTAssertEqual(store.statusText, "Click the ayah to play")
        XCTAssertEqual(PlaybackMode.continuous.title, "Continuous")
        XCTAssertEqual(PlaybackMode.surah.title, "Stop at end of surah")
        XCTAssertEqual(PlaybackMode.repeatAyah.title, "Repeat current ayah")
        XCTAssertEqual(AudioSizes.formatted(0), "0 KB")
        XCTAssertEqual(AudioSizes.formatted(1_706_672_026), "1.71 GB")
    }

    func testModesAdvanceThroughAyahsSurahsAndStopAtQuranEnd() throws {
        let quran = try Quran.load()
        let endFatihah = AyahPosition(surah: 0, ayah: 6)
        XCTAssertEqual(PlaybackMode.continuous.next(in: quran, after: endFatihah), AyahPosition(surah: 1, ayah: 0))
        XCTAssertNil(PlaybackMode.surah.next(in: quran, after: endFatihah))
        XCTAssertNil(PlaybackMode.repeatAyah.next(in: quran, after: endFatihah))
        XCTAssertEqual(quran.previousInQuran(before: AyahPosition(surah: 1, ayah: 0)), endFatihah)
        XCTAssertNil(quran.previousInQuran(before: AyahPosition(surah: 0, ayah: 0)))
        XCTAssertNil(PlaybackMode.continuous.next(in: quran, after: AyahPosition(surah: 113, ayah: 5)))
        var position = AyahPosition(surah: 0, ayah: 0)
        var count = 1
        while let next = PlaybackMode.continuous.next(in: quran, after: position) {
            position = next
            count += 1
        }
        XCTAssertEqual(count, 6236)
        XCTAssertEqual(position, AyahPosition(surah: 113, ayah: 5))
    }

    @MainActor
    func testModePersistsAndNeighborsCrossSurahBoundaries() throws {
        let suite = "FloatingAyahMode.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let quran = try Quran.load()
        let store = PlayerStore(quran: quran, defaults: defaults)
        XCTAssertEqual(store.playbackMode, .continuous)
        store.select(surah: 0, ayah: 6)
        XCTAssertNil(store.nextAyahText)
        store.next()
        XCTAssertEqual(store.position, AyahPosition(surah: 1, ayah: 0))
        XCTAssertTrue(store.isBasmalah)
        XCTAssertNil(store.previousAyahText)
        store.previous()
        XCTAssertEqual(store.position, AyahPosition(surah: 0, ayah: 6))
        store.playbackMode = .surah
        let restored = PlayerStore(quran: quran, defaults: defaults)
        XCTAssertEqual(restored.playbackMode, .surah)
        restored.repeatsAyah = true
        XCTAssertEqual(restored.playbackMode, .repeatAyah)
        restored.repeatsAyah = false
        XCTAssertEqual(restored.playbackMode, .continuous)
    }

    func testPointerMovesBetweenWordsOnSameLineAndClearsOldMarker() throws {
        let scroll = LyricsScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 144))
        let view = ClickableAyahView()
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.heightTracksTextView = false
        scroll.documentView = view
        scroll.text = "بِسْمِ ٱللَّهِ"
        scroll.previousText = "ٱلْحَمْدُ"
        scroll.reduceMotion = true
        let words = TimedAyah.wordRanges(in: scroll.text)
        scroll.readingRange = words[0]
        scroll.updateText()
        let document = try XCTUnwrap(scroll.renderedDocument)
        let first = try XCTUnwrap(document.absoluteReadingRange(words[0]))
        let second = try XCTUnwrap(document.absoluteReadingRange(words[1]))
        XCTAssertEqual(scroll.highlightedWord, first)
        let firstFrame = try XCTUnwrap(scroll.wordMarkerFrame)
        scroll.readingRange = words[1]
        scroll.updateText()
        XCTAssertEqual(scroll.highlightedWord, second)
        // Same line, different word: the marker must move along the line to the new word.
        let secondFrame = try XCTUnwrap(scroll.wordMarkerFrame)
        XCTAssertNotEqual(firstFrame.minX, secondFrame.minX)
        XCTAssertEqual(firstFrame.midY, secondFrame.midY, accuracy: 1)
        scroll.readingRange = nil
        scroll.updateText()
        XCTAssertNil(scroll.highlightedWord)
        XCTAssertNil(scroll.wordMarkerFrame)
        XCTAssertEqual(view.string, document.text)
    }

    func testWholeWindowDragPreservesClickAndUsesScreenCoordinates() {
        let root = NSView()
        let child = NSView()
        root.addSubview(child)
        let drag = WindowDrag(view: root)
        XCTAssertTrue(drag.recognizer.view === root)
        XCTAssertTrue(drag.recognizer.delaysPrimaryMouseButtonEvents)
        XCTAssertEqual(drag.recognizer.buttonMask, 1)
        XCTAssertEqual(WindowDrag.movedOrigin(NSPoint(x: 100, y: 200),
                                             from: NSPoint(x: 500, y: 600),
                                             to: NSPoint(x: 530, y: 570)), NSPoint(x: 130, y: 170))
    }
}
