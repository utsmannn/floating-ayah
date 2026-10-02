import AVFoundation
import Combine
import Foundation

@MainActor
final class ReciterSample: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private let player = AVPlayer()
    private var statusObserver: NSKeyValueObservation?
    private var endObserver: Any?
    private var stallObserver: Any?

    /// Al-Fatihah 1:2 is identical for every preview. Main player is paused by
    /// PlayerStore before this method, and preview never changes its position.
    func play(quran: Quran, reciter: Reciter, files: AudioFiles) {
        stop()
        let url = files.localURL(surah: 1, ayah: 2)
            ?? quran.audioURL(at: AyahPosition(surah: 0, ayah: 1), reciter: reciter)
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        isPlaying = true
        isLoading = true
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                if item.status == .failed {
                    self.stop()
                    self.errorMessage = "Unable to load the sample. Check your internet connection and try again."
                } else if item.status == .readyToPlay {
                    self.isLoading = false
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        stallObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.stop()
                self?.errorMessage = "Sample playback failed. Try again."
            }
        }
        player.play()
    }

    func stop() {
        player.pause()
        statusObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let stallObserver { NotificationCenter.default.removeObserver(stallObserver) }
        endObserver = nil
        stallObserver = nil
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        isLoading = false
        errorMessage = nil
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let stallObserver { NotificationCenter.default.removeObserver(stallObserver) }
    }
}
