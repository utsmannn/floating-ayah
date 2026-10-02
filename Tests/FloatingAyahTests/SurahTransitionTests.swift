import AVFoundation
import XCTest
@testable import FloatingAyah

final class SurahTransitionTests: XCTestCase {
    func testNewSectionRemovesPreviousSurahFromLyricDocument() throws {
        let scroll = LyricsScrollView(frame: NSRect(x: 0, y: 0, width: 364, height: 159))
        let view = ClickableAyahView()
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.heightTracksTextView = false
        scroll.documentView = view
        scroll.reduceMotion = true
        scroll.surahIndex = 0
        scroll.text = "صِرَٰطَ ٱلَّذِينَ"
        scroll.previousText = "ٱهْدِنَا"
        scroll.updateText()
        scroll.surahIndex = 1
        scroll.isOpeningPause = true
        scroll.text = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"
        scroll.previousText = nil
        scroll.nextText = "الٓمٓ"
        scroll.updateText()
        XCTAssertNil(scroll.renderedDocument?.previousRange)
        XCTAssertFalse(view.string.contains("صِرَٰطَ"))
        XCTAssertTrue(view.string.hasPrefix("بِسْمِ"))
        XCTAssertNil(scroll.highlightedWord)
    }

    func testRepeatSurahWrapsWithPauseAndNeverAddsBasmalahToTawbah() throws {
        let quran = try Quran.load()
        XCTAssertEqual(PlaybackMode.repeatSurah.title, "Repeat surah")
        for (index, surah) in quran.surahs.enumerated() {
            let last = PlaybackEntry(position: AyahPosition(surah: index, ayah: surah.ayahs.count - 1), isBasmalah: false)
            let pause = try XCTUnwrap(quran.nextEntry(after: last, mode: .repeatSurah))
            XCTAssertTrue(pause.isSurahPause)
            XCTAssertEqual(pause.position, AyahPosition(surah: index, ayah: 0))
            XCTAssertEqual(pause.isBasmalah, surah.number != 1 && surah.number != 9)
            let opening = try XCTUnwrap(quran.nextEntry(after: pause, mode: .repeatSurah))
            XCTAssertFalse(opening.isSurahPause)
            if surah.number == 9 {
                XCTAssertFalse(opening.isBasmalah)
                XCTAssertEqual(quran.audioURL(at: quran.audioPosition(for: opening)).lastPathComponent, "009001.mp3")
                XCTAssertEqual(quran.text(for: opening), surah.ayahs[0].text)
            }
        }
        let within = PlaybackEntry(position: AyahPosition(surah: 1, ayah: 0), isBasmalah: false)
        XCTAssertFalse(try XCTUnwrap(quran.nextEntry(after: within, mode: .repeatSurah)).isSurahPause)
        let basmalah = quran.openingEntry(at: AyahPosition(surah: 1, ayah: 0))
        XCTAssertFalse(try XCTUnwrap(quran.nextEntry(after: basmalah, mode: .repeatSurah)).isSurahPause)
        XCTAssertNil(quran.nextEntry(after: within, mode: .repeatAyah))
    }

    func testBundledPauseIsExactlyOneSecond() async throws {
        let file = try XCTUnwrap(Quran.resourceBundle.url(forResource: "surah-pause", withExtension: "wav"))
        let duration = try await AVURLAsset(url: file).load(.duration)
        XCTAssertEqual(duration.seconds, 1, accuracy: 0.001)
        let audio = try AVAudioFile(forReading: file)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: audio.processingFormat,
                                                 frameCapacity: AVAudioFrameCount(audio.length)))
        try audio.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData)[0]
        for index in 0..<Int(buffer.frameLength) { XCTAssertEqual(channel[index], 0) }
    }

    @MainActor
    func testQueueTransitionsSilenceOpeningAyahAndHidesPreviousSurah() async throws {
        let quran = try Quran.load()
        let suite = "SurahTransitionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let player = AVQueuePlayer()
        let store = PlayerStore(quran: quran, defaults: defaults, player: player)
        store.select(surah: 0, ayah: 6)
        XCTAssertNil(store.nextAyahText)
        XCTAssertEqual((player.items().last?.asset as? AVURLAsset)?.url.lastPathComponent, "surah-pause.wav")
        player.advanceToNextItem()
        for _ in 0..<50 where !store.isSurahPause { await Task.yield() }
        XCTAssertTrue(store.isSurahPause)
        XCTAssertTrue(store.isBasmalah)
        XCTAssertEqual(store.position, AyahPosition(surah: 1, ayah: 0))
        XCTAssertNil(store.previousAyahText)
        XCTAssertNil(store.previousAyahNumber)
        XCTAssertEqual(store.nextAyahText, "الٓمٓ")
        XCTAssertEqual((player.items().last?.asset as? AVURLAsset)?.url.lastPathComponent, "001001.mp3")
        player.advanceToNextItem()
        for _ in 0..<50 where store.isSurahPause { await Task.yield() }
        XCTAssertFalse(store.isSurahPause)
        XCTAssertTrue(store.isBasmalah)
        XCTAssertEqual((player.items().last?.asset as? AVURLAsset)?.url.lastPathComponent, "002001.mp3")
        player.advanceToNextItem()
        for _ in 0..<50 where store.isBasmalah { await Task.yield() }
        XCTAssertFalse(store.isBasmalah)
        XCTAssertNotNil(store.previousAyahText) // Same-surah basmalah still visible.
        store.playbackMode = .repeatSurah
        XCTAssertEqual(PlayerStore(quran: quran, defaults: defaults).playbackMode, .repeatSurah)
        store.select(surah: 7, ayah: 74)
        store.playbackMode = .continuous
        player.advanceToNextItem()
        for _ in 0..<50 where !store.isSurahPause { await Task.yield() }
        XCTAssertTrue(store.isSurahPause)
        XCTAssertFalse(store.isBasmalah)
        XCTAssertEqual(store.position.surah, 8)
        XCTAssertNil(store.previousAyahText)
        XCTAssertEqual((player.items().last?.asset as? AVURLAsset)?.url.lastPathComponent, "009001.mp3")
    }
}
