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
    var continuousText = false
    var backgroundColor = LyricColor.black
    var backgroundOpacity: Double = 0
    var visibleLines = LyricAppearance.defaultLines

    private enum CodingKeys: String, CodingKey {
        case textColor, shadowColor, shadowEnabled, shadowBlur, shadowDepth
        case shadowOpacity, panelWidth, lineSpacing, ayahNumberScale, continuousText
        case backgroundColor, backgroundOpacity, visibleLines
    }

    static let minLines = 1
    static let maxLines = 10
    static let defaultLines = 3
    static func clampedLines(_ value: Int) -> Int { min(maxLines, max(minLines, value)) }

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
        continuousText = try values.decodeIfPresent(Bool.self, forKey: .continuousText) ?? false
        backgroundColor = try values.decodeIfPresent(LyricColor.self, forKey: .backgroundColor) ?? .black
        backgroundOpacity = try values.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 0
        visibleLines = try values.decodeIfPresent(Int.self, forKey: .visibleLines) ?? Self.defaultLines
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
        value.backgroundOpacity = value.backgroundOpacity.isFinite ? min(1, max(0, value.backgroundOpacity)) : 0
        value.visibleLines = Self.clampedLines(value.visibleLines)
        value.backgroundColor = LyricColor(red: value.backgroundColor.red, green: value.backgroundColor.green, blue: value.backgroundColor.blue)
        value.textColor = LyricColor(red: value.textColor.red, green: value.textColor.green, blue: value.textColor.blue)
        value.shadowColor = LyricColor(red: value.shadowColor.red, green: value.shadowColor.green, blue: value.shadowColor.blue)
        return value
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "lyricAppearance") }
    }
}

struct LyricSegment: Equatable {
    let text: String
    let number: Int?
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
         currentNumber: Int? = nil, previousNumber: Int? = nil, nextNumber: Int? = nil,
         continuousText: Bool = false) {
        let separator = continuousText ? " " : "\n"
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
            content += separator
        } else {
            previousRange = nil
        }
        currentRange = NSRange(location: (content as NSString).length, length: (current as NSString).length)
        content += current
        currentMarkerRange = appendMarker(currentNumber, to: &content)
        if let next {
            content += separator
            nextRange = NSRange(location: (content as NSString).length, length: (next as NSString).length)
            content += next
            _ = appendMarker(nextNumber, to: &content)
        } else {
            nextRange = nil
        }
        text = content
        markerRanges = markers
    }

    /// Whole-surah document: its text never changes while reading, so line breaks stay fixed.
    init(before: [LyricSegment], current: String, currentNumber: Int?, after: [LyricSegment]) {
        var markers: [NSRange] = []
        var content = ""
        // The unnumbered opening basmalah is not part of the surah, so it keeps its own line.
        // Al-Fatihah's basmalah is numbered ayah 1 and flows like any other ayah.
        var afterOpening = false
        func join() -> String { afterOpening ? "\n" : " " }
        func append(_ segment: LyricSegment) {
            afterOpening = segment.number == nil
            content += segment.text
            if let number = segment.number {
                let marker = Self.ayahMarker(number)
                markers.append(NSRange(location: (content as NSString).length, length: (marker as NSString).length))
                content += marker
            }
        }
        for (index, segment) in before.enumerated() {
            if index > 0 { content += join() }
            append(segment)
        }
        previousRange = before.isEmpty ? nil : NSRange(location: 0, length: (content as NSString).length)
        if !content.isEmpty { content += join() }
        currentRange = NSRange(location: (content as NSString).length, length: (current as NSString).length)
        append(LyricSegment(text: current, number: currentNumber))
        currentMarkerRange = currentNumber == nil ? nil : markers.last
        if after.isEmpty {
            nextRange = nil
        } else {
            content += join()
            let start = (content as NSString).length
            for (index, segment) in after.enumerated() {
                if index > 0 { content += join() }
                append(segment)
            }
            nextRange = NSRange(location: start, length: (content as NSString).length - start)
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
