import Foundation

/// Ayahs looped by the repeat-range mode: zero-based ayah indices within one surah.
struct AyahRange: Equatable {
    let surah: Int
    let first: Int
    let last: Int

    var start: AyahPosition { AyahPosition(surah: surah, ayah: first) }

    func contains(_ position: AyahPosition) -> Bool {
        position.surah == surah && (first...last).contains(position.ayah)
    }
}

enum PlaybackMode: String, CaseIterable, Identifiable {
    case continuous
    case surah
    case repeatAyah
    case repeatSurah
    /// Needs a range of ayahs, so it is set up from the menu and never reached by cycling.
    case repeatRange

    /// The modes the panel button cycles through and the menu's mode control offers.
    static let basic: [PlaybackMode] = [.continuous, .surah, .repeatAyah, .repeatSurah]

    var id: String { rawValue }
    var title: String {
        switch self {
        case .continuous: return "Continuous"
        case .surah: return "Stop at end of surah"
        case .repeatAyah: return "Repeat current ayah"
        case .repeatSurah: return "Repeat surah"
        case .repeatRange: return "Repeat ayah range"
        }
    }

    var symbol: String {
        switch self {
        case .continuous: return "arrow.right"
        case .surah: return "stop.circle"
        case .repeatAyah: return "repeat.1"
        case .repeatSurah: return "repeat"
        case .repeatRange: return "repeat.circle"
        }
    }

    /// The following basic mode, wrapping around.
    var cycled: PlaybackMode {
        guard let index = Self.basic.firstIndex(of: self) else { return .continuous }
        return Self.basic[(index + 1) % Self.basic.count]
    }

    func next(in quran: Quran, after position: AyahPosition, range: AyahRange? = nil) -> AyahPosition? {
        switch self {
        case .continuous: return quran.nextInQuran(after: position)
        case .surah: return quran.next(after: position)
        case .repeatAyah: return nil
        case .repeatSurah:
            return quran.next(after: position) ?? AyahPosition(surah: position.surah, ayah: 0)
        case .repeatRange:
            guard let range else { return quran.next(after: position) }
            // Playback before the range runs into it; anything at or past its end returns to its start.
            if position.surah == range.surah, position.ayah < range.last { return quran.next(after: position) }
            return range.start
        }
    }
}
