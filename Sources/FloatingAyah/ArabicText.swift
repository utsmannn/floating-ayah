import AppKit
import SwiftUI

/// The same TextKit configuration is used for measuring and displaying Arabic.
/// No truncation, font shrinking, or changes to the source text.
enum ArabicTypography {
    static func lineHeight(size: Double, spacing: Double = 6) -> CGFloat {
        CGFloat(size * 1.5 + 2 + spacing)
    }

    static func attributed(_ text: String, size: Double, fontName: String = ArabicFonts.defaultName,
                           spacing: Double = 6) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.alignment = .right
        // Quran fonts reserve very tall typographic leading. Use one compact
        // baseline rhythm for both wrapping and paragraph boundaries instead.
        paragraph.lineSpacing = 0
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        paragraph.minimumLineHeight = lineHeight(size: size, spacing: spacing)
        paragraph.maximumLineHeight = lineHeight(size: size, spacing: spacing)
        let font = ArabicFonts.font(name: fontName, size: size)
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph,
            .foregroundColor: NSColor.labelColor
        ])
    }

    static func height(for text: String, size: Double, width: CGFloat, fontName: String = ArabicFonts.defaultName,
                       spacing: Double = 6) -> CGFloat {
        let storage = NSTextStorage(attributedString: attributed(text, size: size, fontName: fontName, spacing: spacing))
        let manager = NSLayoutManager()
        manager.usesFontLeading = false
        let container = NSTextContainer(containerSize: NSSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        return ceil(manager.usedRect(for: container).height) + 4
    }
}

struct ArabicText: NSViewRepresentable {
    let text: String
    let fontSize: Double
    let onClick: () -> Void

    func makeNSView(context: Context) -> ClickableAyahView {
        let view = ClickableAyahView()
        view.isEditable = false
        view.isSelectable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isHorizontallyResizable = false
        // SwiftUI owns the measured frame. NSTextView must not resize itself
        // inside the ScrollView, which can center/crop the start of a long ayah.
        view.isVerticallyResizable = false
        view.textContainer?.heightTracksTextView = false
        view.setAccessibilityRole(.button)
        return view
    }

    func updateNSView(_ view: ClickableAyahView, context: Context) {
        let attributed = ArabicTypography.attributed(text, size: fontSize)
        if view.textStorage?.isEqual(to: attributed) != true {
            view.textStorage?.setAttributedString(attributed)
        }
        view.onClick = onClick
        view.setAccessibilityLabel(text)
        view.setAccessibilityHelp("Click to play or pause audio")
    }
}

final class ClickableAyahView: NSTextView {
    var onClick: (() -> Void)?
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }
}

struct DragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> PanelDragView { PanelDragView() }
    func updateNSView(_ nsView: PanelDragView, context: Context) {}
}

final class PanelDragView: NSView {
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}
