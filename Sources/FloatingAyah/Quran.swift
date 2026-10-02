import Foundation

struct Ayah: Codable, Equatable {
    let number: Int
    let text: String
}

struct Surah: Codable, Identifiable {
    let number: Int
    let name: String
    let arabicName: String
    let ayahs: [Ayah]
    var id: Int { number }
}

struct AyahPosition: Codable, Equatable {
    let surah: Int // Zero-based catalog index.
    let ayah: Int
}

/// Basmalah is a playback/display step, not an extra numbered Quran ayah.
struct PlaybackEntry: Equatable {
    let position: AyahPosition
    let isBasmalah: Bool
    let isSurahPause: Bool

    init(position: AyahPosition, isBasmalah: Bool, isSurahPause: Bool = false) {
        self.position = position
        self.isBasmalah = isBasmalah
        self.isSurahPause = isSurahPause
    }
}

struct Quran {
    let surahs: [Surah]

    static var resourceBundle: Bundle {
        // Packaged .apps must not depend on SwiftPM's absolute build-path fallback.
        let bundle: Bundle
        if Bundle.main.bundleURL.pathExtension == "app",
           let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("FloatingAyah_FloatingAyah.bundle"),
           let packaged = Bundle(url: resourceURL) {
            bundle = packaged
        } else {
            bundle = .module
        }
        return bundle
    }

    static func load() throws -> Quran {
        guard let url = resourceBundle.url(forResource: "quran", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return Quran(surahs: try JSONDecoder().decode([Surah].self, from: Data(contentsOf: url)))
    }

    func contains(_ position: AyahPosition) -> Bool {
        surahs.indices.contains(position.surah)
            && surahs[position.surah].ayahs.indices.contains(position.ayah)
    }

    func next(after position: AyahPosition) -> AyahPosition? {
        guard contains(position), position.ayah + 1 < surahs[position.surah].ayahs.count else { return nil }
        return AyahPosition(surah: position.surah, ayah: position.ayah + 1)
    }

    func previous(before position: AyahPosition) -> AyahPosition? {
        guard contains(position), position.ayah > 0 else { return nil }
        return AyahPosition(surah: position.surah, ayah: position.ayah - 1)
    }

    func nextInQuran(after position: AyahPosition) -> AyahPosition? {
        guard contains(position) else { return nil }
        if let next = next(after: position) { return next }
        let nextSurah = position.surah + 1
        guard surahs.indices.contains(nextSurah), !surahs[nextSurah].ayahs.isEmpty else { return nil }
        return AyahPosition(surah: nextSurah, ayah: 0)
    }

    func previousInQuran(before position: AyahPosition) -> AyahPosition? {
        guard contains(position) else { return nil }
        if let previous = previous(before: position) { return previous }
        let previousSurah = position.surah - 1
        guard surahs.indices.contains(previousSurah), !surahs[previousSurah].ayahs.isEmpty else { return nil }
        return AyahPosition(surah: previousSurah, ayah: surahs[previousSurah].ayahs.count - 1)
    }

    /// The source edition prepends four basmalah words on opening ayahs.
    /// Keep stored Arabic untouched and split only the display/playback view.
    /// Two openings (95/97) use an extra shadda on بِسْمِ in the source.
    static func openingParts(_ text: String, surah: Int) -> (basmalah: String, ayah: String)? {
        guard surah != 1, surah != 9 else { return nil }
        let words = TimedAyah.wordRanges(in: text)
        guard words.count > 4 else { return nil }
        let source = text as NSString
        let expected = ["بسم", "الله", "الرحمن", "الرحيم"]
        for index in 0..<4 {
            let token = source.substring(with: words[index])
            let letters = token.unicodeScalars.filter { $0.properties.generalCategory == .otherLetter }
            let plain = String(String.UnicodeScalarView(letters)).replacingOccurrences(of: "ٱ", with: "ا")
            guard plain == expected[index] else { return nil }
        }
        let end = NSMaxRange(words[3])
        let next = words[4].location
        return (source.substring(to: end), source.substring(from: next))
    }

    func basmalah(at position: AyahPosition) -> String? {
        guard contains(position), position.ayah == 0 else { return nil }
        let surah = surahs[position.surah]
        return Self.openingParts(surah.ayahs[0].text, surah: surah.number)?.basmalah
    }

    func text(at position: AyahPosition) -> String {
        let surah = surahs[position.surah]
        let text = surah.ayahs[position.ayah].text
        if position.ayah == 0, let parts = Self.openingParts(text, surah: surah.number) { return parts.ayah }
        return text
    }

    func openingEntry(at position: AyahPosition) -> PlaybackEntry {
        PlaybackEntry(position: position, isBasmalah: basmalah(at: position) != nil)
    }

    func nextEntry(after entry: PlaybackEntry, mode: PlaybackMode) -> PlaybackEntry? {
        if entry.isSurahPause {
            return PlaybackEntry(position: entry.position, isBasmalah: entry.isBasmalah)
        }
        // Even repeat-one must play the opening once, then repeat ayah 1 only.
        if entry.isBasmalah { return PlaybackEntry(position: entry.position, isBasmalah: false) }
        guard let next = mode.next(in: self, after: entry.position) else { return nil }
        let opening = openingEntry(at: next)
        return PlaybackEntry(position: next, isBasmalah: opening.isBasmalah,
                             isSurahPause: next.surah != entry.position.surah ||
                                (mode == .repeatSurah && self.next(after: entry.position) == nil))
    }

    func text(for entry: PlaybackEntry) -> String {
        entry.isBasmalah ? (basmalah(at: entry.position) ?? text(at: entry.position)) : text(at: entry.position)
    }

    func audioPosition(for entry: PlaybackEntry) -> AyahPosition {
        entry.isBasmalah ? AyahPosition(surah: 0, ayah: 0) : entry.position
    }

    func audioURL(at position: AyahPosition, reciter: Reciter = .alafasy) -> URL {
        let surah = surahs[position.surah]
        let ayah = surah.ayahs[position.ayah]
        let filename = String(format: "%03d%03d.mp3", surah.number, ayah.number)
        return URL(string: "https://everyayah.com/data/\(reciter.rawValue)/\(filename)")!
    }
}
