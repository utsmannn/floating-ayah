import XCTest
@testable import FloatingAyah

final class LocalReciterTests: XCTestCase {
    func testLocalReciterIsOfferedOnlyOnceInstalled() throws {
        XCTAssertTrue(Reciter.ziyaadPatel.isLocal)
        XCTAssertFalse(Reciter.bundled.contains(.ziyaadPatel))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = AudioFiles(root: root)
        XCTAssertFalse(files.isInstalled)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: files.manifest)
        XCTAssertTrue(files.isInstalled)
    }

    /// Recorded: Al-Fatihah, Al-Baqarah 1–5 and Al-Ikhlas. Everything else is a gap.
    @MainActor
    func testOnlyRecordedAyahsArePlayableAndNavigationSkipsGaps() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = AudioFiles(root: root)
        let recorded = (1...7).map { (1, $0) } + (1...5).map { (2, $0) } + (1...4).map { (112, $0) }
        for (surah, ayah) in recorded {
            let url = files.url(surah: surah, ayah: ayah)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("ID3".utf8).write(to: url)
        }
        let suite = "FloatingAyahLocal.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let quran = try Quran.load()
        let offline = OfflineAudio(quran: quran, files: files, reciter: .ziyaadPatel)
        let store = PlayerStore(quran: quran, defaults: defaults, offline: offline)

        XCTAssertEqual(store.availableCount(inSurah: 1), 5)
        XCTAssertEqual(store.availableCount(inSurah: 2), 0)
        XCTAssertTrue(store.isAvailable(AyahPosition(surah: 1, ayah: 4)))
        XCTAssertFalse(store.isAvailable(AyahPosition(surah: 1, ayah: 5)))

        // An unrecorded surah cannot be opened; a recorded one opens at its first ayah.
        XCTAssertFalse(store.open(surah: 2))
        XCTAssertTrue(store.open(surah: 1))
        XCTAssertEqual(store.position, AyahPosition(surah: 1, ayah: 0))
        XCTAssertTrue(store.isBasmalah, "Al-Fatihah 1:1 is recorded, so the basmalah plays")

        // Next from the last recorded ayah jumps the gap to the next recorded one.
        store.select(surah: 1, ayah: 4)
        XCTAssertTrue(store.canGoNext)
        store.next()
        XCTAssertEqual(store.position, AyahPosition(surah: 111, ayah: 0))
        store.previous()
        XCTAssertEqual(store.position, AyahPosition(surah: 1, ayah: 4))
        store.nextSurah()
        XCTAssertEqual(store.position, AyahPosition(surah: 111, ayah: 0), "surahs 3–111 have no recordings")
        store.previousSurah()
        XCTAssertEqual(store.position, AyahPosition(surah: 1, ayah: 0))

        // A gap shows as such and cannot be played.
        store.select(surah: 1, ayah: 10)
        XCTAssertFalse(store.canPlay)
        XCTAssertEqual(store.statusText, "Not recorded by Ziyaad Patel")
        store.play()
        XCTAssertFalse(store.isPlaying)
    }

    @MainActor
    func testBundledReciterTreatsEveryAyahAsAvailable() throws {
        let suite = "FloatingAyahLocal.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PlayerStore(quran: try Quran.load(), defaults: defaults)
        XCTAssertFalse(store.reciter.isLocal)
        XCTAssertTrue(store.isAvailable(AyahPosition(surah: 3, ayah: 150)))
        XCTAssertEqual(store.availableCount(inSurah: 1), 286)
    }
}
