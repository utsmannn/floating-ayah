import Foundation

/// Snapshot of EveryAyah's per-file byte sizes, not an extrapolation from ayah counts.
struct AudioSizes: Decodable {
    let source: String
    let retrievedAt: String
    let files: [String: Int64]

    static func load(reciter: Reciter = .alafasy) throws -> AudioSizes {
        guard let url = Quran.resourceBundle.url(forResource: reciter.sizeResource, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(AudioSizes.self, from: Data(contentsOf: url))
    }

    func total(in quran: Quran) -> Int64? {
        var total: Int64 = 0
        for surah in quran.surahs {
            for ayah in surah.ayahs {
                let filename = String(format: "%03d%03d.mp3", surah.number, ayah.number)
                guard let bytes = files[filename], bytes > 0 else { return nil }
                total += bytes
            }
        }
        return total
    }

    static func formatted(_ bytes: Int64) -> String {
        let amount = max(0, bytes)
        let unit: (divisor: Double, label: String)
        if amount >= 1_000_000_000 { unit = (1_000_000_000, "GB") }
        else if amount >= 1_000_000 { unit = (1_000_000, "MB") }
        else { unit = (1_000, "KB") }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let value = formatter.string(from: NSNumber(value: Double(amount) / unit.divisor)) ?? "0"
        return "\(value) \(unit.label)"
    }
}
