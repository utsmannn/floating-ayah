import Foundation

/// Durable downloads belong in Application Support, not an evictable cache.
struct AudioFiles {
    let root: URL

    static var standard: AudioFiles { standard(reciter: .alafasy) }

    static func standard(reciter: Reciter) -> AudioFiles {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return AudioFiles(root: support.appendingPathComponent("FloatingAyah/Audio/\(reciter.rawValue)", isDirectory: true))
    }

    func url(surah: Int, ayah: Int) -> URL {
        root.appendingPathComponent(String(format: "%03d", surah), isDirectory: true)
            .appendingPathComponent(String(format: "%03d%03d.mp3", surah, ayah))
    }

    func localURL(surah: Int, ayah: Int) -> URL? {
        let file = url(surah: surah, ayah: ayah)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.int64Value > 0 else { return nil }
        return file
    }

    func count(in surah: Surah) -> Int {
        surah.ayahs.filter { localURL(surah: surah.number, ayah: $0.number) != nil }.count
    }

    func size(surah: Int, ayah: Int) -> Int64 {
        guard let local = localURL(surah: surah, ayah: ayah),
              let attributes = try? FileManager.default.attributesOfItem(atPath: local.path) else { return 0 }
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Reject error pages, truncated transfers, and non-MP3 bodies before promotion.
    func install(_ temporary: URL, response: URLResponse, surah: Int, ayah: Int) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: temporary.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard size >= 3, response.expectedContentLength <= 0 || size == response.expectedContentLength else {
            throw URLError(.cannotDecodeContentData)
        }
        let handle = try FileHandle(forReadingFrom: temporary)
        defer { try? handle.close() }
        let prefix = try handle.read(upToCount: 3) ?? Data()
        let bytes = Array(prefix)
        let hasID3 = prefix == Data("ID3".utf8)
        let hasFrame = bytes.count >= 2 && bytes[0] == 0xFF && bytes[1] & 0xE0 == 0xE0
        guard hasID3 || hasFrame else { throw URLError(.cannotDecodeContentData) }
        let destination = url(surah: surah, ayah: ayah)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        // An existing complete file wins; never remove audio while a player uses it.
        if localURL(surah: surah, ayah: ayah) != nil { return }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}

@MainActor
final class OfflineAudio: ObservableObject {
    private(set) var files: AudioFiles
    @Published private(set) var reciter: Reciter
    @Published private(set) var counts: [Int: Int] = [:]
    @Published private(set) var downloadingSurah: Int?
    @Published private(set) var completed = 0
    @Published private(set) var total = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var savedBytes: Int64 = 0
    @Published private(set) var estimatedTotalBytes: Int64?
    private var task: Task<Void, Never>?
    private let session: URLSession

    var isDownloading: Bool { task != nil }
    var progress: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    var savedAyahs: Int { counts.values.reduce(0, +) }

    init(quran: Quran, files: AudioFiles? = nil, session: URLSession = .shared, reciter: Reciter = .alafasy) {
        self.reciter = reciter
        self.files = files ?? .standard(reciter: reciter)
        self.session = session
        estimatedTotalBytes = (try? AudioSizes.load(reciter: reciter))?.total(in: quran)
        refresh(quran: quran)
    }

    /// Switching collections is disabled while a download is running, so files
    /// and progress cannot silently migrate into another qari's folder.
    func select(reciter: Reciter, quran: Quran) {
        guard task == nil, reciter != self.reciter else { return }
        self.reciter = reciter
        files = .standard(reciter: reciter)
        errorMessage = nil
        completed = 0
        total = 0
        estimatedTotalBytes = (try? AudioSizes.load(reciter: reciter))?.total(in: quran)
        refresh(quran: quran)
    }

    func refresh(quran: Quran) {
        counts = Dictionary(uniqueKeysWithValues: quran.surahs.map { ($0.number, files.count(in: $0)) })
        savedBytes = quran.surahs.reduce(0) { total, surah in
            total + surah.ayahs.reduce(0) { $0 + files.size(surah: surah.number, ayah: $1.number) }
        }
    }

    func downloadAll(quran: Quran) {
        guard task == nil, let first = quran.surahs.first else { return }
        refresh(quran: quran)
        errorMessage = nil
        downloadingSurah = first.number
        total = quran.surahs.reduce(0) { $0 + $1.ayahs.count }
        completed = savedAyahs
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.refresh(quran: quran)
                self.downloadingSurah = nil
                self.task = nil
            }
            do {
                for (surahIndex, surah) in quran.surahs.enumerated() {
                    try Task.checkCancellation()
                    self.downloadingSurah = surah.number
                    for (ayahIndex, ayah) in surah.ayahs.enumerated() {
                        try Task.checkCancellation()
                        if self.files.localURL(surah: surah.number, ayah: ayah.number) != nil { continue }
                        let remote = quran.audioURL(at: AyahPosition(surah: surahIndex, ayah: ayahIndex), reciter: self.reciter)
                        let (temporary, response) = try await self.session.download(from: remote)
                        defer { try? FileManager.default.removeItem(at: temporary) }
                        try Task.checkCancellation()
                        try self.files.install(temporary, response: response, surah: surah.number, ayah: ayah.number)
                        self.completed += 1
                        self.savedBytes += self.files.size(surah: surah.number, ayah: ayah.number)
                        self.counts[surah.number, default: 0] += 1
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Quran download failed. Completed files are saved. Click Resume Quran download to try again."
                }
            }
        }
    }

    func cancel() { task?.cancel() }
}
