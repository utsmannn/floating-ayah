import Foundation

/// Forgiving surah lookup: the bundled names are transliterations such as "Al-Baqara" and
/// "Aal-i-Imraan", so people type "baqarah" or "imran" and expect a match.
enum SurahSearch {
    /// Comparison key. Doubled letters ("aa", "ee") fold to one, and e/i, o/u are treated alike,
    /// because transliterations vary ("Yaseen"/"Yasin", "Aal-i-Imraan"/"Ali Imran").
    /// Only exact pairs fold, so a nonsense run such as "zzzz" is not reduced to a real letter.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let letters = folded.filter { $0.isLetter || $0.isNumber }.map { character -> Character in
            switch character {
            case "e": return "i"
            case "o": return "u"
            default: return character
            }
        }
        var result = ""
        var index = 0
        while index < letters.count {
            var end = index
            while end < letters.count, letters[end] == letters[index] { end += 1 }
            let run = end - index
            result += String(repeating: String(letters[index]), count: run == 2 ? 1 : run)
            index = end
        }
        return result
    }

    /// Name without its leading article ("Al-", "An-", "Ash-", ...), so "baqara" finds "Al-Baqara".
    private static func bare(_ name: String) -> String {
        let parts = name.split(separator: "-", maxSplits: 1).map(String.init)
        return parts.count == 2 ? normalize(parts[1]) : normalize(name)
    }

    static func matches(_ query: String, in surahs: [Surah], limit: Int = 6) -> [Surah] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        if let number = Int(trimmed) {
            let exact = surahs.filter { $0.number == number }
            let prefixed = surahs.filter { $0.number != number && String($0.number).hasPrefix(trimmed) }
            return Array((exact + prefixed).prefix(limit))
        }
        var typed = normalize(trimmed)
        if typed.count > 3, typed.hasSuffix("h") { typed.removeLast() } // "baqarah" -> "baqara"
        guard !typed.isEmpty else { return [] }
        let scored: [(Surah, Int)] = surahs.compactMap { surah in
            let full = normalize(surah.name)
            let stripped = bare(surah.name)
            if stripped == typed || full == typed { return (surah, 0) } // Exact name wins.
            if stripped.hasPrefix(typed) { return (surah, 1) }
            if full.hasPrefix(typed) { return (surah, 2) }
            if full.contains(typed) { return (surah, 3) }
            return nil
        }
        return Array(scored.sorted { ($0.1, $0.0.number) < ($1.1, $1.0.number) }.map(\.0).prefix(limit))
    }
}
