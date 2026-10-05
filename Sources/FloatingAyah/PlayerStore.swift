import AVFoundation
import Combine
import Foundation

@MainActor
final class PlayerStore: ObservableObject {
    let quran: Quran
    let offline: OfflineAudio
    let sample = ReciterSample()
    @Published private(set) var reciter: Reciter
    @Published private(set) var position: AyahPosition
    @Published private(set) var isBasmalah = false
    @Published private(set) var isSurahPause = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var readingRange: NSRange?
    private var wordTimings: WordTimings?
    @Published var playbackMode: PlaybackMode {
        didSet {
            guard playbackMode != oldValue else { return }
            defaults.set(playbackMode.rawValue, forKey: "playbackMode")
            if player.currentItem != nil {
                rebuildQueue(play: isPlaying, seekTo: player.currentTime())
            }
        }
    }
    var repeatsAyah: Bool {
        get { playbackMode == .repeatAyah }
        set { playbackMode = newValue ? .repeatAyah : .continuous }
    }
    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: "fontSize") }
    }
    @Published var fontName: String {
        didSet { defaults.set(fontName, forKey: "fontName") }
    }
    @Published var appearance: LyricAppearance {
        didSet { appearance.save(to: defaults) }
    }

    private let defaults: UserDefaults
    private let player: AVQueuePlayer
    private var positions: [ObjectIdentifier: PlaybackEntry] = [:]
    private var observations: [NSKeyValueObservation] = []
    private var itemObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var finishedSurah = false

    var surah: Surah { quran.surahs[position.surah] }
    var ayah: Ayah { surah.ayahs[position.ayah] }
    var currentEntry: PlaybackEntry { PlaybackEntry(position: position, isBasmalah: isBasmalah, isSurahPause: isSurahPause) }
    var displayText: String { quran.text(for: currentEntry) }
    var displayNumber: Int? { isBasmalah ? nil : ayah.number }
    var displayTitle: String { "\(surah.name) · \(isBasmalah ? "Basmalah" : String(ayah.number))" }
    private var previousEntry: PlaybackEntry? {
        if !isBasmalah, quran.basmalah(at: position) != nil {
            return PlaybackEntry(position: position, isBasmalah: true)
        }
        guard let previous = quran.previousInQuran(before: position),
              previous.surah == position.surah else { return nil }
        return PlaybackEntry(position: previous, isBasmalah: false)
    }
    private var nextDisplayEntry: PlaybackEntry? {
        let visibleEntry = PlaybackEntry(position: position, isBasmalah: isBasmalah)
        guard let next = quran.nextEntry(after: visibleEntry, mode: .continuous),
              next.position.surah == position.surah else { return nil }
        return next
    }
    /// Entire surah around the current entry for stable, mushaf-like continuous text.
    var continuousContext: (before: [LyricSegment], after: [LyricSegment])? {
        // Also during the surah pause, so the opening never reflows when its audio starts.
        // Use display text: ayah 1 stores its basmalah inline, but it is shown separately.
        let segments = surah.ayahs.enumerated().map {
            LyricSegment(text: quran.text(at: AyahPosition(surah: position.surah, ayah: $0.offset)),
                         number: $0.element.number)
        }
        if isBasmalah { return ([], segments) }
        var before: [LyricSegment] = []
        // The opening belongs to the surah, so look it up from ayah 1 rather than the current ayah.
        if let opening = quran.basmalah(at: AyahPosition(surah: position.surah, ayah: 0)) {
            before.append(LyricSegment(text: opening, number: nil))
        }
        before += segments[..<position.ayah]
        return (before, Array(segments[(position.ayah + 1)...]))
    }
    var previousAyahText: String? { previousEntry.map { quran.text(for: $0) } }
    var nextAyahText: String? { nextDisplayEntry.map { quran.text(for: $0) } }
    var previousAyahNumber: Int? {
        guard let entry = previousEntry, !entry.isBasmalah else { return nil }
        return quran.surahs[entry.position.surah].ayahs[entry.position.ayah].number
    }
    var nextAyahNumber: Int? {
        guard let entry = nextDisplayEntry, !entry.isBasmalah else { return nil }
        return quran.surahs[entry.position.surah].ayahs[entry.position.ayah].number
    }
    var canGoPrevious: Bool { quran.previousInQuran(before: position) != nil }
    var canGoNext: Bool { isBasmalah || quran.nextInQuran(after: position) != nil }
    var progress: Double { duration > 0 ? min(1, elapsed / duration) : 0 }
    var actionLabel: String { isPlaying ? "Pause" : "Play" }
    var actionIcon: String { isPlaying ? "pause.fill" : "play.fill" }
    var statusText: String {
        if errorMessage != nil { return "Unable to load audio" }
        if isSurahPause { return playbackMode == .repeatSurah ? "Repeating surah…" : "Next surah…" }
        if isBuffering { return "Loading audio…" }
        if finishedSurah { return playbackMode == .continuous ? "Quran completed" : "Surah completed" }
        return isPlaying ? reciter.name : "Click the ayah to play"
    }

    init(quran: Quran, defaults: UserDefaults = .standard, offline: OfflineAudio? = nil,
         player: AVQueuePlayer = AVQueuePlayer()) {
        self.player = player
        self.quran = quran
        let selectedReciter = offline?.reciter ?? Reciter(rawValue: defaults.string(forKey: "reciter") ?? "") ?? .alafasy
        reciter = selectedReciter
        self.offline = offline ?? OfflineAudio(quran: quran, reciter: selectedReciter)
        self.defaults = defaults
        playbackMode = PlaybackMode(rawValue: defaults.string(forKey: "playbackMode") ?? "") ?? .continuous
        fontName = ArabicFonts.resolvedName(defaults.string(forKey: "fontName"))
        appearance = LyricAppearance.load(from: defaults)
        wordTimings = try? WordTimings.load(reciter: selectedReciter)
        let saved = AyahPosition(surah: defaults.integer(forKey: "surah"), ayah: defaults.integer(forKey: "ayah"))
        let initialPosition = quran.contains(saved) ? saved : AyahPosition(surah: 0, ayah: 0)
        position = initialPosition
        isBasmalah = quran.basmalah(at: initialPosition) != nil
        let savedSize = defaults.double(forKey: "fontSize")
        fontSize = savedSize == 0 ? 30 : min(42, max(22, savedSize))
        player.automaticallyWaitsToMinimizeStalling = true
        observations = [
            player.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.reconcileCurrentItem() }
            },
            player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isBuffering = self.isPlaying && self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                }
            }
        ]
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.08, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let time = self.player.currentTime().seconds
                let length = self.player.currentItem?.duration.seconds ?? 0
                self.elapsed = time.isFinite ? max(0, time) : 0
                self.duration = length.isFinite ? max(0, length) : 0
                guard !self.isSurahPause else { self.readingRange = nil; return }
                let audioPosition = self.quran.audioPosition(for: self.currentEntry)
                let audioSurah = self.quran.surahs[audioPosition.surah]
                let range = self.wordTimings?.range(surah: audioSurah.number,
                                                   ayah: audioSurah.ayahs[audioPosition.ayah].number,
                                                   seconds: self.elapsed, text: self.displayText)
                if range != self.readingRange { self.readingRange = range }
            }
        }
        // Audio starts only on an explicit play click.
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    func togglePlayback() {
        if isPlaying { pause() } else { play() }
    }

    func pause() {
        sample.stop()
        player.pause()
        isPlaying = false
        isBuffering = false
    }

    func play() {
        sample.stop()
        guard !isPlaying else { return }
        if player.currentItem == nil || errorMessage != nil || finishedSurah {
            rebuildQueue(play: true)
        } else if let local = localURL(for: currentEntry),
                  (player.currentItem?.asset as? AVURLAsset)?.url != local {
            // A completed download takes effect on resume, without waiting for
            // a previously queued network stream (or interrupting active audio).
            rebuildQueue(play: true, seekTo: player.currentTime())
        } else {
            isPlaying = true
            isBuffering = player.currentItem?.status != .readyToPlay
            player.play()
        }
    }

    func select(surah index: Int, ayah ayahIndex: Int = 0) {
        let selected = AyahPosition(surah: index, ayah: ayahIndex)
        guard quran.contains(selected) else { return }
        sample.stop()
        position = selected
        isBasmalah = quran.basmalah(at: selected) != nil
        isSurahPause = false
        rememberPosition()
        rebuildQueue(play: isPlaying)
    }

    func previous() {
        guard let previous = quran.previousInQuran(before: position) else { return }
        select(surah: previous.surah, ayah: previous.ayah)
    }

    func next() {
        if isSurahPause {
            isSurahPause = false
            rebuildQueue(play: isPlaying)
            return
        }
        if isBasmalah {
            isBasmalah = false
            rebuildQueue(play: isPlaying)
            return
        }
        guard let next = quran.nextInQuran(after: position) else { return }
        select(surah: next.surah, ayah: next.ayah)
    }

    func retry() { sample.stop(); rebuildQueue(play: true) }

    func selectReciter(_ selected: Reciter) {
        guard selected != reciter, !offline.isDownloading else { return }
        let continuePlayback = isPlaying
        sample.stop()
        reciter = selected
        defaults.set(selected.rawValue, forKey: "reciter")
        wordTimings = try? WordTimings.load(reciter: selected)
        isBasmalah = quran.basmalah(at: position) != nil
        isSurahPause = false
        offline.select(reciter: selected, quran: quran)
        // Same verse, but start at zero: timing from one qari isn't transferable.
        if player.currentItem != nil { rebuildQueue(play: continuePlayback) }
        else { readingRange = nil; elapsed = 0; duration = 0 }
    }

    func toggleSample() {
        if sample.isPlaying { sample.stop(); return }
        player.pause()
        isPlaying = false
        isBuffering = false
        sample.play(quran: quran, reciter: reciter, files: offline.files)
    }

    private func rememberPosition() {
        defaults.set(position.surah, forKey: "surah")
        defaults.set(position.ayah, forKey: "ayah")
    }

    private func localURL(for entry: PlaybackEntry) -> URL? {
        if entry.isSurahPause {
            return Quran.resourceBundle.url(forResource: "surah-pause", withExtension: "wav")
        }
        let audio = quran.audioPosition(for: entry)
        let surah = quran.surahs[audio.surah]
        return offline.files.localURL(surah: surah.number, ayah: surah.ayahs[audio.ayah].number)
    }

    private func makeItem(for entry: PlaybackEntry) -> AVPlayerItem {
        let audio = quran.audioPosition(for: entry)
        let item = AVPlayerItem(url: localURL(for: entry) ?? quran.audioURL(at: audio, reciter: reciter))
        item.preferredForwardBufferDuration = 5
        positions[ObjectIdentifier(item)] = entry
        return item
    }

    private func rebuildQueue(play: Bool, seekTo time: CMTime? = nil) {
        player.pause()
        itemObservation = nil
        player.removeAllItems()
        positions.removeAll()
        finishedSurah = false
        errorMessage = nil
        elapsed = 0
        duration = 0
        readingRange = nil
        let item = makeItem(for: currentEntry)
        player.insert(item, after: nil)
        enqueueNext()
        observeItem(item)
        isPlaying = play
        isBuffering = play
        if let time, time.isValid, time.seconds.isFinite {
            // AVPlayer holds playback until the asynchronous seek completes.
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if play { player.play() }
    }

    private func enqueueNext() {
        guard player.items().count < 2,
              let last = player.items().last,
              let lastPosition = positions[ObjectIdentifier(last)],
              let next = quran.nextEntry(after: lastPosition, mode: playbackMode) else { return }
        player.insert(makeItem(for: next), after: last)
    }

    private func reconcileCurrentItem() {
        guard let item = player.currentItem else {
            guard isPlaying else { return }
            if repeatsAyah {
                rebuildQueue(play: true)
            } else {
                isPlaying = false
                isBuffering = false
                finishedSurah = true
                elapsed = duration
            }
            return
        }
        guard let itemPosition = positions[ObjectIdentifier(item)] else { return }
        if currentEntry != itemPosition {
            position = itemPosition.position
            isBasmalah = itemPosition.isBasmalah
            isSurahPause = itemPosition.isSurahPause
            rememberPosition()
            elapsed = 0
            duration = 0
            readingRange = nil
        }
        // Keep only the current and next item, not the whole surah in memory.
        let liveIDs = Set(player.items().map(ObjectIdentifier.init))
        positions = positions.filter { liveIDs.contains($0.key) }
        enqueueNext()
        observeItem(item)
    }

    private func observeItem(_ item: AVPlayerItem) {
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                if item.status == .failed {
                    self.player.pause()
                    self.isPlaying = false
                    self.isBuffering = false
                    self.errorMessage = "Unable to load audio. Check your downloads or internet connection, then try again."
                } else {
                    self.isBuffering = self.isPlaying && (
                        item.status == .unknown || self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                    )
                }
            }
        }
    }
}
