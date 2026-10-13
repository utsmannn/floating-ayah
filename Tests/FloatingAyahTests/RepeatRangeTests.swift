import AVFoundation
import XCTest
@testable import FloatingAyah

final class RepeatRangeTests: XCTestCase {
    private let jumuah = 61

    func testRangeLoopsWithinSurahWithoutReplayingTheOpening() throws {
        let quran = try Quran.load()
        let range = AyahRange(surah: jumuah, first: 0, last: 4)
        func next(_ ayah: Int, basmalah: Bool = false) throws -> PlaybackEntry {
            let entry = PlaybackEntry(position: AyahPosition(surah: jumuah, ayah: ayah), isBasmalah: basmalah)
            return try XCTUnwrap(quran.nextEntry(after: entry, mode: .repeatRange, range: range))
        }
        XCTAssertEqual(try next(0, basmalah: true), PlaybackEntry(position: range.start, isBasmalah: false))
        XCTAssertEqual(try next(2), PlaybackEntry(position: AyahPosition(surah: jumuah, ayah: 3), isBasmalah: false))
        XCTAssertEqual(try next(4), PlaybackEntry(position: range.start, isBasmalah: false))
        // Past the range, playback returns to its start; before it, playback runs into it.
        XCTAssertEqual(try next(9), PlaybackEntry(position: range.start, isBasmalah: false))
        let middle = AyahRange(surah: jumuah, first: 5, last: 7)
        let early = PlaybackEntry(position: AyahPosition(surah: jumuah, ayah: 2), isBasmalah: false)
        XCTAssertEqual(quran.nextEntry(after: early, mode: .repeatRange, range: middle)?.position.ayah, 3)
        let one = AyahRange(surah: jumuah, first: 3, last: 3)
        let single = PlaybackEntry(position: one.start, isBasmalah: false)
        XCTAssertEqual(quran.nextEntry(after: single, mode: .repeatRange, range: one), single)
    }

    @MainActor
    func testRepeatingARangeQueuesItsStartAndEndsWhenLeavingTheSurah() async throws {
        let quran = try Quran.load()
        let suite = "RepeatRangeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let player = AVQueuePlayer()
        let store = PlayerStore(quran: quran, defaults: defaults, player: player)
        store.playbackMode = .surah
        store.select(surah: jumuah, ayah: 7)
        store.repeatAyahs(from: 1, to: 2)
        XCTAssertEqual(store.playbackMode, .repeatRange)
        XCTAssertEqual(store.position, AyahPosition(surah: jumuah, ayah: 1))
        XCTAssertEqual(store.playbackModeTitle, "Repeat ayahs 2–3")
        player.advanceToNextItem()
        for _ in 0..<50 where store.position.ayah != 2 { await Task.yield() }
        XCTAssertEqual(store.position, AyahPosition(surah: jumuah, ayah: 2))
        XCTAssertEqual((player.items().last?.asset as? AVURLAsset)?.url.lastPathComponent, "062002.mp3")

        let restored = PlayerStore(quran: quran, defaults: defaults)
        XCTAssertEqual(restored.playbackMode, .repeatRange)
        XCTAssertEqual(restored.repeatRange, AyahRange(surah: jumuah, first: 1, last: 2))

        store.select(surah: jumuah, ayah: 9) // Same surah: the range stays.
        XCTAssertEqual(store.playbackMode, .repeatRange)
        store.select(surah: 0)
        XCTAssertEqual(store.playbackMode, .surah)
        XCTAssertEqual(store.repeatRange, AyahRange(surah: jumuah, first: 1, last: 2))

        store.select(surah: jumuah)
        store.repeatAyahs(from: 0, to: 0)
        XCTAssertEqual(store.playbackModeTitle, "Repeat ayah 1")
        store.cyclePlaybackMode()
        XCTAssertEqual(store.playbackMode, .surah)
    }

    @MainActor
    func testInvalidRangesAreIgnored() throws {
        let quran = try Quran.load()
        let suite = "RepeatRangeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PlayerStore(quran: quran, defaults: defaults)
        store.select(surah: jumuah)
        store.repeatAyahs(from: 4, to: 2)
        store.repeatAyahs(from: 0, to: 11)
        XCTAssertEqual(store.playbackMode, .continuous)
        XCTAssertNil(store.repeatRange)
        defaults.set("repeatRange", forKey: "playbackMode") // A mode saved without its range.
        XCTAssertEqual(PlayerStore(quran: quran, defaults: defaults).playbackMode, .continuous)
    }
}
