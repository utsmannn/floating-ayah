import AppKit
import SwiftUI

struct LyricColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let white = LyricColor(red: 1, green: 1, blue: 1)
    static let black = LyricColor(red: 0, green: 0, blue: 0)

    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
    var color: Color { Color(nsColor: nsColor) }

    init(red: Double, green: Double, blue: Double) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
    }

    init(_ color: Color) {
        let rgb = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }
}

struct LyricAppearance: Codable, Equatable {
    var textColor = LyricColor.white
    var shadowColor = LyricColor.black
    var shadowEnabled = true
    var shadowBlur: Double = 4
    var shadowDepth: Double = 1
    var shadowOpacity: Double = 0.9
    var panelWidth: Double = 420
    var lineSpacing: Double = 6
    var ayahNumberScale: Double = 1

    private enum CodingKeys: String, CodingKey {
        case textColor, shadowColor, shadowEnabled, shadowBlur, shadowDepth
        case shadowOpacity, panelWidth, lineSpacing, ayahNumberScale
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        textColor = try values.decodeIfPresent(LyricColor.self, forKey: .textColor) ?? .white
        shadowColor = try values.decodeIfPresent(LyricColor.self, forKey: .shadowColor) ?? .black
        shadowEnabled = try values.decodeIfPresent(Bool.self, forKey: .shadowEnabled) ?? true
        shadowBlur = try values.decodeIfPresent(Double.self, forKey: .shadowBlur) ?? 4
        shadowDepth = try values.decodeIfPresent(Double.self, forKey: .shadowDepth) ?? 1
        shadowOpacity = try values.decodeIfPresent(Double.self, forKey: .shadowOpacity) ?? 0.9
        panelWidth = try values.decodeIfPresent(Double.self, forKey: .panelWidth) ?? 420
        lineSpacing = try values.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? 6
        ayahNumberScale = try values.decodeIfPresent(Double.self, forKey: .ayahNumberScale) ?? 1
    }

    var shadow: NSShadow? {
        guard shadowEnabled else { return nil }
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor.nsColor.withAlphaComponent(shadowOpacity)
        shadow.shadowBlurRadius = shadowBlur
        shadow.shadowOffset = NSSize(width: 0, height: -shadowDepth)
        return shadow
    }

    static func load(from defaults: UserDefaults) -> LyricAppearance {
        guard let data = defaults.data(forKey: "lyricAppearance"),
              var value = try? JSONDecoder().decode(LyricAppearance.self, from: data) else { return LyricAppearance() }
        value.lineSpacing = value.lineSpacing.isFinite ? min(24, max(0, value.lineSpacing)) : 6
        value.ayahNumberScale = value.ayahNumberScale.isFinite ? min(1.2, max(0.6, value.ayahNumberScale)) : 1
        value.panelWidth = value.panelWidth.isFinite ? min(800, max(280, value.panelWidth)) : 420
        value.shadowDepth = value.shadowDepth.isFinite ? min(16, max(0, value.shadowDepth)) : 1
        value.shadowBlur = value.shadowBlur.isFinite ? min(20, max(0, value.shadowBlur)) : 4
        value.shadowOpacity = value.shadowOpacity.isFinite ? min(1, max(0, value.shadowOpacity)) : 0.9
        value.textColor = LyricColor(red: value.textColor.red, green: value.textColor.green, blue: value.textColor.blue)
        value.shadowColor = LyricColor(red: value.shadowColor.red, green: value.shadowColor.green, blue: value.shadowColor.blue)
        return value
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "lyricAppearance") }
    }
}

/// The source Arabic is kept verbatim; offsets account only for separators.
struct LyricsDocument: Equatable {
    let text: String
    let currentRange: NSRange
    let previousRange: NSRange?
    let nextRange: NSRange?
    let markerRanges: [NSRange]
    let currentMarkerRange: NSRange?

    static func ayahMarker(_ number: Int) -> String {
        let digits = Array("٠١٢٣٤٥٦٧٨٩")
        let numeral = String(number).compactMap { $0.wholeNumberValue }.map { String(digits[$0]) }.joined()
        return "\u{00A0}﴿\(numeral)﴾"
    }

    init(current: String, previous: String?, next: String?,
         currentNumber: Int? = nil, previousNumber: Int? = nil, nextNumber: Int? = nil) {
        var markers: [NSRange] = []
        func appendMarker(_ number: Int?, to content: inout String) -> NSRange? {
            guard let number else { return nil }
            let marker = Self.ayahMarker(number)
            let range = NSRange(location: (content as NSString).length, length: (marker as NSString).length)
            content += marker
            markers.append(range)
            return range
        }
        var content = ""
        if let previous {
            previousRange = NSRange(location: 0, length: (previous as NSString).length)
            content = previous
            _ = appendMarker(previousNumber, to: &content)
            content += "\n"
        } else {
            previousRange = nil
        }
        currentRange = NSRange(location: (content as NSString).length, length: (current as NSString).length)
        content += current
        currentMarkerRange = appendMarker(currentNumber, to: &content)
        if let next {
            content += "\n"
            nextRange = NSRange(location: (content as NSString).length, length: (next as NSString).length)
            content += next
            _ = appendMarker(nextNumber, to: &content)
        } else {
            nextRange = nil
        }
        text = content
        markerRanges = markers
    }

    func absoluteReadingRange(_ relative: NSRange?) -> NSRange? {
        guard let relative, relative.length > 0, relative.location >= 0,
              NSMaxRange(relative) <= currentRange.length else { return nil }
        return NSRange(location: currentRange.location + relative.location, length: relative.length)
    }
}
