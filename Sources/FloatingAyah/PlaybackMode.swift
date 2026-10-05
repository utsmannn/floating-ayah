import Foundation

enum PlaybackMode: String, CaseIterable, Identifiable {
    case continuous
    case surah
    case repeatAyah
    case repeatSurah

    var id: String { rawValue }
    var title: String {
        switch self {
        case .continuous: return "Continuous"
        case .surah: return "Stop at end of surah"
        case .repeatAyah: return "Repeat current ayah"
        case .repeatSurah: return "Repeat surah"
        }
    }

    var symbol: String {
        switch self {
        case .continuous: return "arrow.right"
        case .surah: return "stop.circle"
        case .repeatAyah: return "repeat.1"
        case .repeatSurah: return "repeat"
        }
    }

    /// The following mode in menu order, wrapping around.
    var cycled: PlaybackMode {
        let all = Self.allCases
        return all[((all.firstIndex(of: self) ?? 0) + 1) % all.count]
    }

    func next(in quran: Quran, after position: AyahPosition) -> AyahPosition? {
        switch self {
        case .continuous: return quran.nextInQuran(after: position)
        case .surah: return quran.next(after: position)
        case .repeatAyah: return nil
        case .repeatSurah:
            return quran.next(after: position) ?? AyahPosition(surah: position.surah, ayah: 0)
        }
    }
}
