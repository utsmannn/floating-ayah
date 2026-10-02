import Foundation

struct TimedAyah: Codable {
    let surah: Int
    let ayah: Int
    // quran-align: [first word, exclusive end word, start milliseconds, end milliseconds].
    let segments: [[Int]]

    func readingRange(at seconds: Double, in text: String) -> NSRange? {
        guard seconds.isFinite else { return nil }
        let milliseconds = Int(max(0, seconds) * 1000)
        // Keep the last spoken span during pauses; repeat phrases can move backwards.
        guard let segment = segments.last(where: { $0.count == 4 && $0[2] <= milliseconds }),
              segment[0] >= 0, segment[1] > segment[0] else { return nil }
        var words = Self.wordRanges(in: text)
        // Al Quran Cloud prepends basmalah; these timing files index the verse
        // itself. Preserve the displayed source, but skip its four prefix words.
        if ayah == 1, Quran.openingParts(text, surah: surah) != nil {
            words.removeFirst(4)
        }
        // A few source verses have incompatible tokenization/missing spans.
        // Prefer manual scroll to silently pointing at the wrong part of Quran.
        let expectedCount = segments.filter { $0.count == 4 }.map { $0[1] }.max()
        guard expectedCount == words.count, segment[1] <= words.count else { return nil }
        let first = words[segment[0]]
        let last = words[segment[1] - 1]
        return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
    }

    static func wordRanges(in text: String) -> [NSRange] {
        guard let expression = try? NSRegularExpression(pattern: "\\S+") else { return [] }
        let length = (text as NSString).length
        return expression.matches(in: text, range: NSRange(location: 0, length: length)).compactMap { match in
            let token = (text as NSString).substring(with: match.range)
            // Standalone waqaf marks count as whitespace tokens in the API,
            // but are not spoken words in the upstream alignment corpus.
            let containsLetter = token.unicodeScalars.contains { scalar in
                switch scalar.properties.generalCategory {
                case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
                    return true
                default:
                    return false
                }
            }
            return containsLetter ? match.range : nil
        }
    }
}

struct WordTimings {
    let ayahs: [String: TimedAyah]

    static func load(reciter: Reciter = .alafasy) throws -> WordTimings {
        let bundle = Quran.resourceBundle
        guard let url = bundle.url(forResource: reciter.timingResource, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONDecoder().decode([TimedAyah].self, from: Data(contentsOf: url))
        return WordTimings(ayahs: Dictionary(data.map { ("\($0.surah):\($0.ayah)", $0) }, uniquingKeysWith: { first, _ in first }))
    }

    func range(surah: Int, ayah: Int, seconds: Double, text: String) -> NSRange? {
        ayahs["\(surah):\(ayah)"]?.readingRange(at: seconds, in: text)
    }
}
