import AVFoundation
import XCTest
@testable import FloatingAyah

final class ReciterTests: XCTestCase {
    func testEachCollectionHasMatchingURLsTimingsSizesAndIsolatedStorage() throws {
        let quran = try Quran.load()
        XCTAssertEqual(Reciter.allCases.count, 6)
        var roots = Set<URL>()
        for reciter in Reciter.allCases {
            let url = quran.audioURL(at: AyahPosition(surah: 0, ayah: 1), reciter: reciter)
            XCTAssertEqual(url.lastPathComponent, "001002.mp3")
            XCTAssertTrue(url.path.contains(reciter.rawValue))
            let timings = try WordTimings.load(reciter: reciter)
            XCTAssertEqual(timings.ayahs.count, 6236)
            XCTAssertNotNil(timings.range(surah: 1, ayah: 2, seconds: 100,
                                         text: quran.surahs[0].ayahs[1].text))
            let sizes = try AudioSizes.load(reciter: reciter)
            XCTAssertEqual(sizes.files.count, 6236)
            XCTAssertGreaterThan(try XCTUnwrap(sizes.total(in: quran)), 800_000_000)
            roots.insert(AudioFiles.standard(reciter: reciter).root)
            // All segments preserve their four-element upstream shape and word bounds.
            for timing in timings.ayahs.values {
                for span in timing.segments {
                    XCTAssertEqual(span.count, 4)
                    XCTAssertGreaterThanOrEqual(span[0], 0)
                    XCTAssertGreaterThan(span[1], span[0])
                }
            }
        }
        XCTAssertEqual(roots.count, 6)
        XCTAssertTrue(AudioFiles.standard.root.path.hasSuffix("Alafasy_128kbps"))
    }

    @MainActor
    func testReciterSelectionPersistsAndKeepsAyahPosition() throws {
        let suite = "FloatingAyahReciter.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let quran = try Quran.load()
        let store = PlayerStore(quran: quran, defaults: defaults)
        XCTAssertEqual(store.reciter, .alafasy)
        store.select(surah: 1, ayah: 281)
        store.selectReciter(.husary)
        XCTAssertEqual(store.position, AyahPosition(surah: 1, ayah: 281))
        XCTAssertEqual(store.reciter, .husary)
        XCTAssertEqual(store.offline.reciter, .husary)
        XCTAssertNil(store.readingRange)
        XCTAssertFalse(store.isPlaying)
        XCTAssertFalse(store.sample.isPlaying)
        let restored = PlayerStore(quran: quran, defaults: defaults)
        XCTAssertEqual(restored.reciter, .husary)
        XCTAssertTrue(restored.offline.files.root.path.hasSuffix(Reciter.husary.rawValue))
        defaults.set("unknown-collection", forKey: "reciter")
        XCTAssertEqual(PlayerStore(quran: quran, defaults: defaults).reciter, .alafasy)
    }

    @MainActor
    func testPreviewStopIsSafeAndDoesNotStartAtLaunch() {
        let sample = ReciterSample()
        XCTAssertFalse(sample.isPlaying)
        sample.stop()
        sample.stop()
        XCTAssertFalse(sample.isPlaying)
        XCTAssertFalse(sample.isLoading)
        XCTAssertNil(sample.errorMessage)
    }

    func testLiveSampleFilesDecodeForEveryReciter() async throws {
        guard ProcessInfo.processInfo.environment["FLOATING_AYAH_LIVE_TEST"] == "1" else {
            throw XCTSkip("Opt in to download six small preview clips and decode them locally")
        }
        let quran = try Quran.load()
        for reciter in Reciter.allCases {
            let url = quran.audioURL(at: AyahPosition(surah: 0, ayah: 1), reciter: reciter)
            let (file, response) = try await URLSession.shared.download(from: url)
            defer { try? FileManager.default.removeItem(at: file) }
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            let library = AudioFiles(root: FileManager.default.temporaryDirectory
                .appendingPathComponent("ReciterSample-\(UUID().uuidString)"))
            defer { try? FileManager.default.removeItem(at: library.root) }
            // Use the real validated download path, with its .mp3 extension,
            // rather than CFNetwork's .tmp URL (AVFoundation uses the suffix).
            try library.install(file, response: response, surah: 1, ayah: 2)
            let local = try XCTUnwrap(library.localURL(surah: 1, ayah: 2))
            let duration = try await AVURLAsset(url: local).load(.duration)
            XCTAssertGreaterThan(duration.seconds, 1, reciter.name)
            print("Decoded preview: \(reciter.name), \(duration.seconds) seconds")
        }
    }
}
