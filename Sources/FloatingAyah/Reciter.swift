import Foundation

/// Collection IDs are shared by audio URLs, timing resources, and offline folders.
/// Local reciters have no download source: their ayah files and timings are placed in the
/// offline folder by `scripts/local-reciter`, and they appear only once that folder is installed.
enum Reciter: String, CaseIterable, Identifiable {
    case alafasy = "Alafasy_128kbps"
    case husary = "Husary_64kbps"
    case minshawi = "Minshawy_Murattal_128kbps"
    case abdulBasit = "Abdul_Basit_Murattal_64kbps"
    case sudais = "Abdurrahmaan_As-Sudais_192kbps"
    case shatri = "Abu_Bakr_Ash-Shaatree_128kbps"
    case ziyaadPatel = "Ziyaad_Patel"

    var id: String { rawValue }
    var name: String {
        switch self {
        case .alafasy: return "Mishary Rashid Alafasy"
        case .husary: return "Mahmoud Khalil Al-Husary"
        case .minshawi: return "Mohamed Siddiq Al-Minshawi"
        case .abdulBasit: return "Abdul Basit Abdus Samad"
        case .sudais: return "Abdurrahman As-Sudais"
        case .shatri: return "Abu Bakr Ash-Shatri"
        case .ziyaadPatel: return "Ziyaad Patel"
        }
    }
    var isLocal: Bool { self == .ziyaadPatel }
    /// EveryAyah collections, which ship timing and size resources in the app bundle.
    static var bundled: [Reciter] { allCases.filter { !$0.isLocal } }
    /// Reciters to offer: every bundled one, plus local ones whose recordings are installed.
    static var available: [Reciter] {
        allCases.filter { !$0.isLocal || AudioFiles.standard(reciter: $0).isInstalled }
    }
    var bitrate: Int {
        switch self {
        case .husary, .abdulBasit: return 64
        case .sudais: return 192
        default: return 128
        }
    }
    var details: String { isLocal ? "Local recordings · \(bitrate) kbps" : "Murattal · \(bitrate) kbps" }
    var timingResource: String { self == .alafasy ? "alafasy-timings" : rawValue + "-timings" }
    var sizeResource: String { self == .alafasy ? "audio-sizes" : rawValue + "-sizes" }
}
