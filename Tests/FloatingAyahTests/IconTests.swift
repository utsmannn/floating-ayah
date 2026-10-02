import AppKit
import XCTest
@testable import FloatingAyah

final class IconTests: XCTestCase {
    func testMenuBarLogoIsBundledWithTransparentCanvas() throws {
        let url = try XCTUnwrap(Quran.resourceBundle.url(forResource: "MenuBarIcon", withExtension: "png"))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
        XCTAssertEqual(bitmap.pixelsWide, 44)
        XCTAssertEqual(bitmap.pixelsHigh, 26)
        XCTAssertTrue(bitmap.hasAlpha)
        XCTAssertLessThan(bitmap.colorAt(x: 0, y: 0)?.alphaComponent ?? 1, 0.01)
        var visible = 0
        for row in 0..<bitmap.pixelsHigh {
            for column in 0..<bitmap.pixelsWide {
                if (bitmap.colorAt(x: column, y: row)?.alphaComponent ?? 0) > 0.3 { visible += 1 }
            }
        }
        XCTAssertGreaterThan(visible, 100)
        let image = try XCTUnwrap(NSImage(contentsOf: url))
        image.isTemplate = true
        XCTAssertTrue(image.isTemplate)
    }
}
