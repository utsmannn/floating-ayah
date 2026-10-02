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
