import XCTest
@testable import FloatingAyah

final class MenuInputTests: XCTestCase {
    private func names(_ query: String) throws -> [String] {
        SurahSearch.matches(query, in: try Quran.load().surahs).map(\.name)
    }

    func testSurahSearchFindsByNameWithoutTheArticleOrExactSpelling() throws {
        XCTAssertEqual(try names("baqara").first, "Al-Baqara")
        XCTAssertEqual(try names("baqarah").first, "Al-Baqara") // Common alternate spelling.
        XCTAssertEqual(try names("AL-BAQ").first, "Al-Baqara")
        XCTAssertEqual(try names("fatiha").first, "Al-Faatiha")
        XCTAssertEqual(try names("yasin").first, "Yaseen") // Most common alternate spelling.
        XCTAssertEqual(try names("yaseen").first, "Yaseen")
        XCTAssertTrue(try names("imran").contains("Aal-i-Imraan"))
        XCTAssertTrue(try names("tawb").contains("At-Tawba"))
    }

    func testSurahSearchByNumberAndEmptyOrUnknownQueries() throws {
        let surahs = try Quran.load().surahs
        XCTAssertEqual(SurahSearch.matches("2", in: surahs).first?.number, 2)
        XCTAssertEqual(SurahSearch.matches("114", in: surahs).map(\.number), [114])
        XCTAssertTrue(SurahSearch.matches("999", in: surahs).isEmpty)
        XCTAssertTrue(SurahSearch.matches("   ", in: surahs).isEmpty)
        XCTAssertTrue(SurahSearch.matches("zzzz", in: surahs).isEmpty)
        XCTAssertLessThanOrEqual(SurahSearch.matches("a", in: surahs, limit: 6).count, 6)
    }

    func testPrefixMatchesRankBeforeLooseMatches() throws {
        // "nas" is exactly An-Naas; it must beat the prefix-only match An-Nasr.
        XCTAssertEqual(try names("nas").first, "An-Naas")
        XCTAssertTrue(try names("nas").contains("An-Nasr"))
        XCTAssertEqual(try names("nasr").first, "An-Nasr")
    }

    func testFiveSwatchesEachAndSelectionByColor() {
        XCTAssertEqual(ColorSwatch.text.count, 5)
        XCTAssertEqual(ColorSwatch.dark.count, 5)
        for set in [ColorSwatch.text, ColorSwatch.dark] {
            XCTAssertEqual(Set(set.map(\.name)).count, 5)
            for (index, swatch) in set.enumerated() {
                XCTAssertTrue(swatch.matches(swatch.color))
                for (other, candidate) in set.enumerated() where other != index {
                    XCTAssertFalse(swatch.matches(candidate.color), "\(swatch.name) vs \(candidate.name)")
                }
            }
        }
        XCTAssertTrue(ColorSwatch.text[0].matches(LyricAppearance().textColor), "default text color is a swatch")
        XCTAssertTrue(ColorSwatch.dark[0].matches(LyricAppearance().backgroundColor))
        XCTAssertTrue(ColorSwatch.dark[0].matches(LyricAppearance().shadowColor))
    }
}
