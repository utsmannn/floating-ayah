import XCTest
@testable import FloatingAyah

final class UpdateCheckerTests: XCTestCase {
    func testVersionsCompareNumerically() {
        XCTAssertTrue(UpdateChecker.isNewer("0.1.4", than: "0.1.3"))
        XCTAssertTrue(UpdateChecker.isNewer("v0.1.10", than: "0.1.9"))
        XCTAssertTrue(UpdateChecker.isNewer("0.2", than: "0.1.9"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0.0", than: "0.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.3", than: "0.1.3"))
        XCTAssertFalse(UpdateChecker.isNewer("0.2", than: "0.2.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.2", than: "0.1.3"))
    }

    @MainActor
    func testReportsNewerRelease() async {
        let checker = UpdateChecker(currentVersion: "0.1.3") { Self.release("v0.1.4") }
        await checker.check()
        XCTAssertEqual(checker.state, .available(version: "0.1.4",
                                                 url: URL(string: "https://github.com/utsmannn/floating-ayah/releases/tag/v0.1.4")!))
        XCTAssertTrue(checker.hasUpdate)
    }

    @MainActor
    func testSameOrOlderReleaseIsUpToDate() async {
        let same = UpdateChecker(currentVersion: "0.1.3") { Self.release("v0.1.3") }
        await same.check()
        XCTAssertEqual(same.state, .upToDate)
        let older = UpdateChecker(currentVersion: "0.1.4") { Self.release("v0.1.3") }
        await older.check()
        XCTAssertEqual(older.state, .upToDate)
        XCTAssertFalse(older.hasUpdate)
    }

    @MainActor
    func testFailuresAreReportedAndUnbundledBuildsNeverCheck() async {
        let failing = UpdateChecker(currentVersion: "0.1.3") { throw URLError(.notConnectedToInternet) }
        await failing.check()
        XCTAssertEqual(failing.state, .failed)
        let malformed = UpdateChecker(currentVersion: "0.1.3") { Data("{}".utf8) }
        await malformed.check()
        XCTAssertEqual(malformed.state, .failed)
        var fetched = false
        let unbundled = UpdateChecker(currentVersion: nil) { fetched = true; return Self.release("v9.9.9") }
        await unbundled.check()
        unbundled.startAutomaticChecks()
        XCTAssertEqual(unbundled.state, .idle)
        XCTAssertFalse(fetched)
    }

    private static func release(_ tag: String) -> Data {
        Data("""
        {"tag_name": "\(tag)", "html_url": "https://github.com/utsmannn/floating-ayah/releases/tag/\(tag)"}
        """.utf8)
    }
}
