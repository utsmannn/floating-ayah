import AVFoundation
import MediaPlayer
import XCTest
@testable import FloatingAyah

final class MediaControlsTests: XCTestCase {
    @MainActor
    func testPlayAndPauseAreIdempotentAndToggleWorks() throws {
        let suite = "MediaControlsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let files = AudioFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent(suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: files.root)
        }
        let quran = try Quran.load()
        let silence = try XCTUnwrap(Quran.resourceBundle.url(forResource: "surah-pause", withExtension: "wav"))
        let local = files.url(surah: 1, ayah: 1)
        try FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: silence, to: local)
        let queue = AVQueuePlayer()
        let store = PlayerStore(quran: quran, defaults: defaults,
                                offline: OfflineAudio(quran: quran, files: files), player: queue)
        store.playbackMode = .repeatAyah
        let controls = MediaControls(store: store)
        XCTAssertFalse(store.isPlaying) // Registering commands must not autoplay.
        controls.handle(.pause)
        XCTAssertNil(queue.currentItem)
        controls.handle(.play)
        XCTAssertTrue(store.isPlaying)
        let first = try XCTUnwrap(queue.currentItem)
        controls.handle(.play)
        XCTAssertTrue(queue.currentItem === first)
        XCTAssertTrue(store.isPlaying)
        controls.handle(.pause)
        controls.handle(.pause)
        XCTAssertFalse(store.isPlaying)
        XCTAssertEqual(queue.rate, 0)
        XCTAssertTrue(queue.currentItem === first)
        controls.handle(.toggle)
        XCTAssertTrue(store.isPlaying)
        controls.handle(.toggle)
        XCTAssertFalse(store.isPlaying)
    }

    @MainActor
    func testNowPlayingMetadataTracksSelectionAndReciter() throws {
        let suite = "MediaMetadataTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PlayerStore(quran: try Quran.load(), defaults: defaults)
        store.select(surah: 1, ayah: 254)
        store.selectReciter(.husary)
        let info = MediaControls.metadata(for: store)
        XCTAssertEqual(info[MPMediaItemPropertyTitle] as? String, "\(store.surah.name) · 255")
        XCTAssertEqual(info[MPMediaItemPropertyArtist] as? String, Reciter.husary.name)
        XCTAssertEqual(info[MPMediaItemPropertyAlbumTitle] as? String, "Floating Ayah")
        XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 0)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 0)
        XCTAssertNil(info[MPMediaItemPropertyPlaybackDuration])
        store.select(surah: 1)
        XCTAssertTrue(store.isBasmalah)
        XCTAssertEqual(MediaControls.metadata(for: store)[MPMediaItemPropertyTitle] as? String,
                       "\(store.surah.name) · Basmalah")
    }
}
