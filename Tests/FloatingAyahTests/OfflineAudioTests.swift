import Foundation
import XCTest
@testable import FloatingAyah

final class OfflineAudioTests: XCTestCase {
    func testSizeManifestCoversExactQuranCatalog() throws {
        let sizes = try AudioSizes.load()
        XCTAssertEqual(sizes.files.count, 6236)
        XCTAssertEqual(sizes.total(in: try Quran.load()), 1_706_672_026)
        XCTAssertEqual(sizes.files["001001.mp3"], 146_830)
        XCTAssertNil(sizes.total(in: Quran(surahs: [
            Surah(number: 999, name: "Unknown", arabicName: "Unknown", ayahs: [Ayah(number: 1, text: "test")])
        ])))
    }

    private func temporaryFiles() -> AudioFiles {
        AudioFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func response(status: Int = 200, length: Int = 8) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: URL(string: "https://example.com/001001.mp3")!,
                                     statusCode: status, httpVersion: nil,
                                     headerFields: ["Content-Length": "\(length)", "Content-Type": "audio/mpeg"]))
    }

    func testInstallPersistsCompleteAudioAcrossInstances() throws {
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let temp = files.root.appendingPathExtension("part")
        defer { try? FileManager.default.removeItem(at: temp) }
        try Data("ID3audio".utf8).write(to: temp)
        XCTAssertNil(files.localURL(surah: 1, ayah: 1))
        try files.install(temp, response: response(), surah: 1, ayah: 1)
        let reopened = AudioFiles(root: files.root)
        let local = try XCTUnwrap(reopened.localURL(surah: 1, ayah: 1))
        XCTAssertEqual(local.lastPathComponent, "001001.mp3")
        XCTAssertEqual(try Data(contentsOf: local), Data("ID3audio".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.path))
        let surah = Surah(number: 1, name: "Test", arabicName: "Test", ayahs: [Ayah(number: 1, text: "test"), Ayah(number: 2, text: "test")])
        XCTAssertEqual(reopened.count(in: surah), 1)
    }

    func testRejectsServerErrorHTMLAndTruncatedAudio() throws {
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let temp = files.root.appendingPathExtension("part")
        defer { try? FileManager.default.removeItem(at: temp) }
        try Data("ID3audio".utf8).write(to: temp)
        XCTAssertThrowsError(try files.install(temp, response: response(status: 404), surah: 1, ayah: 1))
        XCTAssertThrowsError(try files.install(temp, response: response(length: 100), surah: 1, ayah: 1))
        try Data("<html>error</html>".utf8).write(to: temp)
        XCTAssertThrowsError(try files.install(temp, response: response(length: 18), surah: 1, ayah: 1))
        XCTAssertNil(files.localURL(surah: 1, ayah: 1))
    }

    func testIncompleteEmptyFilesAreNotMarkedOffline() throws {
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let file = files.url(surah: 2, ayah: 282)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: file)
        XCTAssertNil(files.localURL(surah: 2, ayah: 282))
    }

    @MainActor
    func testWholeQuranIncludesEverySurahAndKeepsCompletedFilesOnFailure() async throws {
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let quran = Quran(surahs: [
            Surah(number: 1, name: "First", arabicName: "First", ayahs: [Ayah(number: 1, text: "test")]),
            Surah(number: 2, name: "Second", arabicName: "Second", ayahs: [Ayah(number: 1, text: "test")])
        ])
        let temp = files.root.appendingPathExtension("part")
        try Data("ID3audio".utf8).write(to: temp)
        try files.install(temp, response: response(), surah: 1, ayah: 1)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RejectNetworkProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let offline = OfflineAudio(quran: quran, files: files, session: session)
        let stopped = expectation(description: "Download stops on connection failure")
        let subscription = offline.$downloadingSurah.dropFirst().filter { $0 == nil }.sink { _ in stopped.fulfill() }
        defer { subscription.cancel() }
        offline.downloadAll(quran: quran)
        XCTAssertEqual(offline.total, 2)
        XCTAssertEqual(offline.completed, 1)
        await fulfillment(of: [stopped], timeout: 5)
        XCTAssertNotNil(offline.errorMessage)
        XCTAssertEqual(offline.savedAyahs, 1)
        XCTAssertNotNil(files.localURL(surah: 1, ayah: 1))
        XCTAssertNil(files.localURL(surah: 2, ayah: 1))
    }

    @MainActor
    func testCompleteQuranDownloadSkipsNetworkAndRestoresCount() async throws {
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let quran = Quran(surahs: [Surah(number: 1, name: "Test", arabicName: "Test", ayahs: [Ayah(number: 1, text: "test")])])
        let temp = files.root.appendingPathExtension("part")
        try Data("ID3audio".utf8).write(to: temp)
        try files.install(temp, response: response(), surah: 1, ayah: 1)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RejectNetworkProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let offline = OfflineAudio(quran: quran, files: files, session: session)
        XCTAssertEqual(offline.counts[1], 1)
        XCTAssertEqual(offline.savedBytes, 8)
        offline.downloadAll(quran: quran)
        for _ in 0..<20 where offline.isDownloading { await Task.yield() }
        XCTAssertFalse(offline.isDownloading)
        XCTAssertNil(offline.errorMessage)
        XCTAssertEqual(offline.completed, 1)
    }
}

/// Any attempted network access fails: complete offline surahs must skip it.
final class RejectNetworkProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
