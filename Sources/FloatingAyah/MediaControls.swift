import Combine
import Foundation
import MediaPlayer

/// Registers system media commands once for the running app, not for every store.
@MainActor
final class MediaControls {
    enum Action {
        case play, pause, toggle
    }

    private weak var store: PlayerStore?
    private let infoCenter: MPNowPlayingInfoCenter
    private var targets: [(MPRemoteCommand, Any)] = []
    private var subscriptions: Set<AnyCancellable> = []
    private var hasStartedPlayback = false

    init(store: PlayerStore, commandCenter: MPRemoteCommandCenter = .shared(),
         infoCenter: MPNowPlayingInfoCenter = .default()) {
        self.store = store
        self.infoCenter = infoCenter
        register(commandCenter.playCommand, action: .play)
        register(commandCenter.pauseCommand, action: .pause)
        register(commandCenter.togglePlayPauseCommand, action: .toggle)

        // Published notifications precede mutation. Deliver on the next main turn
        // so metadata reflects the final queue/selection/state, including failures.
        store.objectWillChange.merge(with: store.sample.objectWillChange)
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateNowPlaying() }
            }
            .store(in: &subscriptions)
    }

    private func register(_ command: MPRemoteCommand, action: Action) {
        command.isEnabled = true
        let token = command.addTarget { [weak self] _ in
            // System command handlers need not arrive on the main actor.
            Task { @MainActor in self?.handle(action) }
            return .success
        }
        targets.append((command, token))
    }

    func handle(_ action: Action) {
        guard let store else { return }
        switch action {
        case .play: store.play()
        case .pause: store.pause()
        case .toggle:
            if store.sample.isPlaying { store.pause() }
            else { store.togglePlayback() }
        }
        updateNowPlaying()
    }

    static func metadata(for store: PlayerStore) -> [String: Any] {
        let preview = store.sample.isPlaying
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: preview ? "Al-Fatihah · Sample" : store.displayTitle,
            MPMediaItemPropertyArtist: store.reciter.name,
            MPMediaItemPropertyAlbumTitle: "Floating Ayah",
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyPlaybackRate: (store.isPlaying || preview) ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: preview ? 0.0 : store.elapsed
        ]
        if !preview, store.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = store.duration
        }
        return info
    }

    private func updateNowPlaying() {
        guard let store else { return }
        let playing = store.isPlaying || store.sample.isPlaying
        hasStartedPlayback = hasStartedPlayback || playing
        // Do not take over another app's Now Playing slot merely at launch.
        guard hasStartedPlayback else { return }
        infoCenter.nowPlayingInfo = Self.metadata(for: store)
        infoCenter.playbackState = playing ? .playing : .paused
    }

    deinit {
        for (command, token) in targets { command.removeTarget(token) }
    }
}
