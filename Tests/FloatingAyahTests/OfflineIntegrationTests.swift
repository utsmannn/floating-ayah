import AVFoundation
import Combine
import XCTest
@testable import FloatingAyah

final class OfflineIntegrationTests: XCTestCase {
    /// Opt-in network smoke test: download just Al-Fatihah into a temporary library,
    /// then verify every ayah is playable from disk with AVFoundation.
    @MainActor
    func testLiveSurahDownloadAndLocalAudioDecoding() async throws {
        guard ProcessInfo.processInfo.environment["FLOATING_AYAH_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set FLOATING_AYAH_LIVE_TEST=1 for the seven-file live download smoke test")
        }
        let quran = try Quran.load()
        let files = AudioFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: files.root) }
        let offline = OfflineAudio(quran: quran, files: files)
        let finished = expectation(description: "Al-Fatihah download completes")
        let subscription = offline.$downloadingSurah.dropFirst().filter { $0 == nil }.sink { _ in finished.fulfill() }
        defer { subscription.cancel(); offline.cancel() }
        // Exercise the same whole-catalog path with a seven-file test catalog,
        // without downloading all 6,236 files just to verify networking.
        offline.downloadAll(quran: Quran(surahs: [quran.surahs[0]]))
        await fulfillment(of: [finished], timeout: 90)
        XCTAssertNil(offline.errorMessage)
        XCTAssertEqual(offline.counts[1], 7)
        let restored = OfflineAudio(quran: quran, files: files)
        XCTAssertEqual(restored.counts[1], 7)
        for ayah in quran.surahs[0].ayahs {
            let local = try XCTUnwrap(restored.files.localURL(surah: 1, ayah: ayah.number))
            XCTAssertTrue(local.isFileURL)
            let duration = try await AVURLAsset(url: local).load(.duration)
            XCTAssertGreaterThan(duration.seconds, 0)
        }
    }
}
