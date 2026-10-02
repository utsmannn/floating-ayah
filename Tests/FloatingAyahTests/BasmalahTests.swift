import AVFoundation
import XCTest
@testable import FloatingAyah

final class BasmalahTests: XCTestCase {
    func testLiveBasmalahFilesDecodeForAllReciters() async throws {
        guard ProcessInfo.processInfo.environment["FLOATING_AYAH_LIVE_TEST"] == "1" else {
            throw XCTSkip("Opt in to validate six basmalah recordings")
        }
        let quran = try Quran.load()
        for reciter in Reciter.allCases {
            let opening = quran.openingEntry(at: AyahPosition(surah: 1, ayah: 0))
            let url = quran.audioURL(at: quran.audioPosition(for: opening), reciter: reciter)
            let (temporary, response) = try await URLSession.shared.download(from: url)
            defer { try? FileManager.default.removeItem(at: temporary) }
            let library = AudioFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
            defer { try? FileManager.default.removeItem(at: library.root) }
            try library.install(temporary, response: response, surah: 1, ayah: 1)
            let local = try XCTUnwrap(library.localURL(surah: 1, ayah: 1))
            let duration = try await AVURLAsset(url: local).load(.duration)
            XCTAssertGreaterThan(duration.seconds, 1, reciter.name)
            print("Basmalah decoded: \(reciter.name), \(duration.seconds) seconds")
        }
    }

    func testAllOpeningsSplitWithoutChangingCorpusOrEmbeddedBasmalah() throws {
        let quran = try Quran.load()
        var count = 0
        for (index, surah) in quran.surahs.enumerated() {
            let position = AyahPosition(surah: index, ayah: 0)
            let original = surah.ayahs[0].text
            if surah.number == 1 || surah.number == 9 {
                XCTAssertNil(quran.basmalah(at: position))
                XCTAssertEqual(quran.text(at: position), original)
            } else {
                let basmalah = try XCTUnwrap(quran.basmalah(at: position), "Surah \(surah.number)")
                let ayah = quran.text(at: position)
                XCTAssertEqual(basmalah + " " + ayah, original)
                XCTAssertEqual(TimedAyah.wordRanges(in: basmalah).count, 4)
                XCTAssertNil(Quran.openingParts(ayah, surah: surah.number))
                count += 1
            }
        }
        XCTAssertEqual(count, 112)
        let embedded = AyahPosition(surah: 26, ayah: 29)
        XCTAssertEqual(quran.text(at: embedded), quran.surahs[26].ayahs[29].text)
        XCTAssertEqual(quran.surahs.reduce(0) { $0 + $1.ayahs.count }, 6236)
    }

    func testPlaybackPlanAddsOpeningOnceAndRespectsTawbahRepeatAndBoundaries() throws {
        let quran = try Quran.load()
        let baqarah = AyahPosition(surah: 1, ayah: 0)
        let opening = quran.openingEntry(at: baqarah)
        XCTAssertTrue(opening.isBasmalah)
        XCTAssertEqual(quran.audioPosition(for: opening), AyahPosition(surah: 0, ayah: 0))
        let ayahOne = try XCTUnwrap(quran.nextEntry(after: opening, mode: .repeatAyah))
        XCTAssertFalse(ayahOne.isBasmalah)
        XCTAssertEqual(ayahOne.position, baqarah)
        XCTAssertNil(quran.nextEntry(after: ayahOne, mode: .repeatAyah))
        let fatihahEnd = PlaybackEntry(position: AyahPosition(surah: 0, ayah: 6), isBasmalah: false)
        let pause = try XCTUnwrap(quran.nextEntry(after: fatihahEnd, mode: .continuous))
        XCTAssertTrue(pause.isSurahPause)
        XCTAssertEqual(quran.nextEntry(after: pause, mode: .continuous), opening)
        XCTAssertNil(quran.nextEntry(after: fatihahEnd, mode: .surah))
        let anfalEnd = PlaybackEntry(position: AyahPosition(surah: 7, ayah: 74), isBasmalah: false)
        let tawbah = try XCTUnwrap(quran.nextEntry(after: anfalEnd, mode: .continuous))
        XCTAssertEqual(tawbah.position, AyahPosition(surah: 8, ayah: 0))
        XCTAssertFalse(tawbah.isBasmalah)
        var step = quran.openingEntry(at: AyahPosition(surah: 0, ayah: 0))
        var openings = step.isBasmalah ? 1 : 0
        var total = 1
        while let next = quran.nextEntry(after: step, mode: .continuous) {
            total += 1
            if next.isBasmalah && !next.isSurahPause { openings += 1 }
            step = next
        }
        XCTAssertEqual(openings, 112)
        XCTAssertEqual(total, 6236 + 112 + 113)
    }

    func testOpeningAndAyahUseTheirOwnTimingsForAllReciters() throws {
        let quran = try Quran.load()
        let position = AyahPosition(surah: 1, ayah: 0)
        for reciter in Reciter.allCases {
            let timings = try WordTimings.load(reciter: reciter)
            let basmalah = try XCTUnwrap(quran.basmalah(at: position))
            let marker = try XCTUnwrap(timings.range(surah: 1, ayah: 1, seconds: 100, text: basmalah))
            XCTAssertEqual(NSMaxRange(marker), (basmalah as NSString).length)
            let firstAyah = quran.text(at: position)
            let firstMarker = try XCTUnwrap(timings.range(surah: 2, ayah: 1, seconds: 100, text: firstAyah))
            XCTAssertEqual((firstAyah as NSString).substring(with: firstMarker), firstAyah)
        }
    }

    @MainActor
    func testActualQueueUsesBasmalahThenVerseWithNoNumberOnOpening() async throws {
        let quran = try Quran.load()
        let suite = "BasmalahTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let player = AVQueuePlayer()
        let store = PlayerStore(quran: quran, defaults: defaults, player: player)
        store.select(surah: 1)
        XCTAssertTrue(store.isBasmalah)
        XCTAssertNil(store.displayNumber)
        XCTAssertEqual(store.nextAyahText, "الٓمٓ")
        XCTAssertEqual(player.items().compactMap { ($0.asset as? AVURLAsset)?.url.lastPathComponent }, ["001001.mp3", "002001.mp3"])
        player.advanceToNextItem()
        for _ in 0..<30 where store.isBasmalah { await Task.yield() }
        XCTAssertFalse(store.isBasmalah)
        XCTAssertEqual(store.position, AyahPosition(surah: 1, ayah: 0))
        XCTAssertEqual(store.displayText, "الٓمٓ")
        XCTAssertEqual(store.displayNumber, 1)
        XCTAssertNotNil(store.previousAyahText)
        XCTAssertNil(store.previousAyahNumber)
        store.select(surah: 8)
        XCTAssertFalse(store.isBasmalah)
        XCTAssertEqual((player.currentItem?.asset as? AVURLAsset)?.url.lastPathComponent, "009001.mp3")
        store.select(surah: 94) // Source has shadda in its basmalah prefix.
        XCTAssertTrue(store.isBasmalah)
        XCTAssertTrue(store.nextAyahText?.hasPrefix("وَٱلتِّينِ") == true)
        store.next()
        XCTAssertFalse(store.isBasmalah)
        XCTAssertEqual(store.displayNumber, 1)
    }
}
