import AppKit
import XCTest
@testable import FloatingAyah

final class QuranTests: XCTestCase {
    func testCatalogIsCompleteAndOrdered() throws {
        let quran = try Quran.load()
        XCTAssertEqual(quran.surahs.count, 114)
        XCTAssertEqual(quran.surahs.reduce(0) { $0 + $1.ayahs.count }, 6236)
        for (index, surah) in quran.surahs.enumerated() {
            XCTAssertEqual(surah.number, index + 1)
            XCTAssertFalse(surah.name.isEmpty)
            for (index, ayah) in surah.ayahs.enumerated() {
                XCTAssertEqual(ayah.number, index + 1)
                XCTAssertFalse(ayah.text.isEmpty)
            }
        }
    }

    func testAudioAddressesUseSurahLocalAyahNumbers() throws {
        let quran = try Quran.load()
        XCTAssertEqual(quran.audioURL(at: AyahPosition(surah: 0, ayah: 0)).lastPathComponent, "001001.mp3")
        XCTAssertEqual(quran.audioURL(at: AyahPosition(surah: 1, ayah: 281)).lastPathComponent, "002282.mp3")
        XCTAssertEqual(quran.audioURL(at: AyahPosition(surah: 113, ayah: 5)).lastPathComponent, "114006.mp3")
    }

    func testNavigationStopsAtSurahBoundaries() throws {
        let quran = try Quran.load()
        XCTAssertNil(quran.previous(before: AyahPosition(surah: 0, ayah: 0)))
        XCTAssertNil(quran.next(after: AyahPosition(surah: 0, ayah: 6)))
        XCTAssertEqual(quran.next(after: AyahPosition(surah: 0, ayah: 0)), AyahPosition(surah: 0, ayah: 1))
        XCTAssertEqual(quran.previous(before: AyahPosition(surah: 0, ayah: 1)), AyahPosition(surah: 0, ayah: 0))
        XCTAssertFalse(quran.contains(AyahPosition(surah: -1, ayah: 0)))
        XCTAssertFalse(quran.contains(AyahPosition(surah: 114, ayah: 0)))
        XCTAssertFalse(quran.contains(AyahPosition(surah: 0, ayah: 7)))
    }

    func testLongArabicAyahWrapsWithoutChangingWidthOrFont() throws {
        let quran = try Quran.load()
        let short = PanelLayout(text: quran.surahs[0].ayahs[2].text, fontSize: 30, availableHeight: 800)
        let long = PanelLayout(text: quran.surahs[1].ayahs[281].text, fontSize: 30, availableHeight: 800)
        XCTAssertGreaterThan(long.textHeight, short.textHeight * 8)
        XCTAssertTrue(long.needsScroll)
        XCTAssertFalse(short.needsScroll)
        XCTAssertLessThanOrEqual(long.height, 800)
        XCTAssertEqual(PanelLayout.width, 420)
        XCTAssertEqual(PanelLayout.textWidth, 420)
        let large = PanelLayout(text: quran.surahs[1].ayahs[281].text, fontSize: 42, availableHeight: 600)
        XCTAssertGreaterThan(large.textHeight, long.textHeight)
        XCTAssertLessThanOrEqual(large.height, 600)
    }

    @MainActor
    func testInvalidSavedPositionFallsBackAndPauseNavigationIsSafe() throws {
        let suite = "FloatingAyahTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(999, forKey: "surah")
        defaults.set(3, forKey: "fontSize")
        let store = PlayerStore(quran: try Quran.load(), defaults: defaults)
        XCTAssertEqual(store.position, AyahPosition(surah: 0, ayah: 0))
        XCTAssertEqual(store.fontSize, 22)
        XCTAssertFalse(store.isPlaying)
        store.previous()
        XCTAssertEqual(store.position.ayah, 0)
        store.select(surah: 999)
        XCTAssertEqual(store.position.surah, 0)
        store.select(surah: 1, ayah: 281)
        XCTAssertEqual(defaults.integer(forKey: "surah"), 1)
        XCTAssertEqual(defaults.integer(forKey: "ayah"), 281)
        XCTAssertFalse(store.isPlaying)
    }
}
