import AppKit
import QuartzCore
import SwiftUI

struct LyricsText: NSViewRepresentable {
    let text: String
    let surahIndex: Int
    let isOpeningPause: Bool
    let previousText: String?
    let nextText: String?
    let currentNumber: Int?
    let previousNumber: Int?
    let nextNumber: Int?
    var surahBefore: [LyricSegment]?
    var surahAfter: [LyricSegment]?
    var isPlaying = false
    let fontSize: Double
    let fontName: String
    let appearance: LyricAppearance
    let readingRange: NSRange?
    let reduceMotion: Bool
    let onClick: () -> Void

    func makeNSView(context: Context) -> LyricsScrollView {
        let scroll = LyricsScrollView()
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.verticalScrollElasticity = .none
        scroll.horizontalScrollElasticity = .none
        scroll.contentView.drawsBackground = false
        let view = ClickableAyahView(frame: .zero)
        view.isEditable = false
        view.isSelectable = false
        view.drawsBackground = false
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.heightTracksTextView = false
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = false
        view.setAccessibilityRole(.button)
        scroll.documentView = view
        scroll.wantsLayer = true
        return scroll
    }

    func updateNSView(_ scroll: LyricsScrollView, context: Context) {
        scroll.onClick = onClick
        scroll.text = text
        scroll.surahIndex = surahIndex
        scroll.isOpeningPause = isOpeningPause
        scroll.previousText = previousText
        scroll.nextText = nextText
        scroll.currentNumber = currentNumber
        scroll.previousNumber = previousNumber
        scroll.nextNumber = nextNumber
        scroll.surahBefore = surahBefore
        scroll.surahAfter = surahAfter
        scroll.isPlaying = isPlaying
        scroll.fontSize = fontSize
        scroll.fontName = fontName
        scroll.lyricAppearance = appearance
        scroll.readingRange = readingRange
        scroll.reduceMotion = reduceMotion
        scroll.updateText()
    }

    static func dismantleNSView(_ scroll: LyricsScrollView, coordinator: ()) { scroll.stopAnimation() }
}

/// One continuous TextKit document prevents a hard boundary between ayahs.
/// The source text isn't edited, split into arbitrary strings, or font-shrunk.
final class LyricsScrollView: NSScrollView {
    var text = ""
    var surahIndex = 0
    var isOpeningPause = false
    private var renderedSurahIndex: Int?
    private var renderedOpeningPause = false
    var previousText: String?
    var nextText: String?
    var currentNumber: Int?
    var previousNumber: Int?
    var nextNumber: Int?
    var surahBefore: [LyricSegment]?
    var surahAfter: [LyricSegment]?
    var isPlaying = false
    var fontSize: Double = 30
    var fontName = ArabicFonts.defaultName
    var lyricAppearance = LyricAppearance()
    var readingRange: NSRange?
    var reduceMotion = false
    var onClick: (() -> Void)?
    private(set) var renderedDocument: LyricsDocument?
    private var renderedSize: Double = 0
    private var renderedFont = ""
    private var renderedAppearance: LyricAppearance?
    private var measuredWidth: CGFloat = 0
    private var lastLineY: CGFloat?
    private var highlightedLine: NSRange?
    private(set) var highlightedWord: NSRange?
    /// Target frames of the animated highlight layers, in document coordinates.
    private(set) var wordMarkerFrame: NSRect?
    private(set) var lineBackgroundFrame: NSRect?
    private let lineLayer = CALayer()
    let wordLayer = CALayer()
    let underlineLayer = CALayer()
    private var scrollTimer: Timer?
    private var animationStart: CFTimeInterval = 0
    private var animationFrom: CGFloat = 0
    private var animationTarget: CGFloat = 0
    private let animationDuration: Double = 0.45
    private var updating = false

    override func layout() {
        super.layout()
        guard !updating else { return }
        let widthChanged = measuredWidth != contentSize.width
        layoutDocument()
        if widthChanged { lastLineY = nil; highlightedLine = nil; highlightedWord = nil }
        followReading()
    }

    func updateText() {
        guard let view = documentView as? ClickableAyahView else { return }
        updating = true
        defer { updating = false }
        view.wantsLayer = true
        let document: LyricsDocument
        if lyricAppearance.continuousText, let before = surahBefore, let after = surahAfter {
            document = LyricsDocument(before: before, current: text, currentNumber: currentNumber, after: after)
        } else {
            document = LyricsDocument(current: text, previous: previousText, next: nextText,
                                      currentNumber: currentNumber, previousNumber: previousNumber, nextNumber: nextNumber,
                                      continuousText: lyricAppearance.continuousText)
        }
        let sectionChanged = renderedSurahIndex != nil &&
            (renderedSurahIndex != surahIndex || (isOpeningPause && !renderedOpeningPause))
        renderedSurahIndex = surahIndex
        renderedOpeningPause = isOpeningPause
        if sectionChanged, !reduceMotion, window != nil {
            // Fade out the old lyric surface as the clean opening replaces it.
            // Rendering remains inside this view; no desktop capture is used.
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.3
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer?.add(fade, forKey: "surah-change")
        }
        let documentChanged = renderedDocument != document
        let styleChanged = renderedSize != fontSize || renderedFont != fontName || renderedAppearance != lyricAppearance
        if documentChanged || styleChanged {
            let oldDocument = renderedDocument
            let oldOffset = contentView.bounds.minY
            let oldCurrentY = oldDocument.flatMap { lineRect(for: $0.currentRange)?.minY }
            stopAnimation()
            renderedDocument = document
            renderedSize = fontSize
            renderedFont = fontName
            renderedAppearance = lyricAppearance
            let styled = NSMutableAttributedString(attributedString:
                ArabicTypography.attributed(document.text, size: fontSize, fontName: fontName,
                                           spacing: lyricAppearance.lineSpacing,
                                           justified: lyricAppearance.continuousText))
            let full = NSRange(location: 0, length: styled.length)
            styled.addAttribute(.foregroundColor, value: lyricAppearance.textColor.nsColor.withAlphaComponent(0.3), range: full)
            styled.addAttribute(.foregroundColor, value: lyricAppearance.textColor.nsColor, range: document.currentRange)
            if let shadow = lyricAppearance.shadow {
                styled.addAttributes([
                    .shadow: shadow,
                    .strokeColor: lyricAppearance.shadowColor.nsColor.withAlphaComponent(lyricAppearance.shadowOpacity),
                    .strokeWidth: -1.5
                ], range: full)
            }
            for range in document.markerRanges {
                styled.addAttributes([
                    .font: ArabicFonts.font(name: ArabicFonts.quranName, size: fontSize * lyricAppearance.ayahNumberScale),
                    .baselineOffset: fontSize * 0.03
                ], range: range)
            }
            if let marker = document.currentMarkerRange {
                styled.addAttribute(.foregroundColor, value: lyricAppearance.textColor.nsColor, range: marker)
            }
            view.layoutManager?.usesFontLeading = false
            view.textStorage?.setAttributedString(styled)
            view.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            // Same surah text: the old word's frame is still valid, so keep the marker and let it
            // glide from the last word of the previous ayah to the first word of this one.
            let keepsMarker = !styleChanged && !sectionChanged && oldDocument?.text == document.text
            if !keepsMarker { clearWordPointer(manager: view.layoutManager) }
            measuredWidth = 0
            lastLineY = nil
            highlightedLine = nil
            layoutDocument()
            // On natural advancement, the old current ayah becomes the new
            // previous ayah. Preserve its screen position before moving onward.
            if documentChanged, !styleChanged, !sectionChanged, lyricAppearance.continuousText,
               let oldDocument, oldDocument.text == document.text {
                // Same surah text: only the current ayah moved, so nothing reflows.
                setScroll(oldOffset)
            } else if documentChanged, !styleChanged, !sectionChanged, let oldDocument, let previous = document.previousRange,
               (document.text as NSString).substring(with: previous)
                    == (oldDocument.text as NSString).substring(with: oldDocument.currentRange),
               let oldCurrentY, let newPreviousY = lineRect(for: previous)?.minY {
                setScroll(oldOffset + newPreviousY - oldCurrentY)
            } else if documentChanged {
                setScroll(0)
            }
        }
        view.onClick = onClick
        view.setAccessibilityLabel(text)
        view.setAccessibilityHelp("Click to play or pause. Drag to move the window. The recited word is highlighted.")
        layoutDocument()
        followReading()
        if sectionChanged {
            // No scrolling through the previous surah during the crossfade.
            stopAnimation()
            if let view = documentView as? NSTextView, let line = lineRect(for: document.currentRange) {
                setScroll(line.midY + view.textContainerInset.height - contentSize.height / 2)
            }
        }
    }

    private func layoutDocument() {
        guard let view = documentView as? NSTextView, renderedDocument != nil,
              contentSize.width > 0 else { return }
        let width = contentSize.width
        // Extra vertical room keeps the first/last line away from the fade edges.
        let inset = max(6, contentSize.height / 2 - ArabicTypography.lineHeight(size: fontSize, spacing: lyricAppearance.lineSpacing) / 2)
        if measuredWidth == width && view.textContainerInset.height == inset { return }
        measuredWidth = width
        view.textContainerInset = NSSize(width: 0, height: inset)
        // Measure the actual styled document, including smaller number markers.
        // Measuring a plain string could wrap a marker onto an extra line.
        view.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        let manager = view.layoutManager
        if let container = view.textContainer { manager?.ensureLayout(for: container) }
        let height = view.textContainer.map { ceil(manager?.usedRect(for: $0).height ?? 0) + 4 } ?? 0
        view.frame = NSRect(x: 0, y: 0, width: width, height: max(height + inset * 2, contentSize.height))
    }

    private func lineRect(for range: NSRange) -> NSRect? {
        guard let view = documentView as? NSTextView,
              let manager = view.layoutManager, let container = view.textContainer,
              range.length > 0, range.location < view.string.utf16.count else { return nil }
        manager.ensureLayout(for: container)
        let glyph = manager.glyphIndexForCharacter(at: range.location)
        return manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
    }

    private func followReading() {
        guard let document = renderedDocument, let view = documentView as? NSTextView,
              let manager = view.layoutManager,
              let line = lineRect(for: document.absoluteReadingRange(readingRange) ?? document.currentRange) else { return }
        updateHighlight(document: document, manager: manager)
        guard lastLineY != line.minY else {
            if reduceMotion, scrollTimer != nil { stopAnimation(); setScroll(animationTarget) }
            return
        }
        lastLineY = line.minY
        let target = boundedOffset(line.midY + view.textContainerInset.height - contentSize.height / 2)
        if reduceMotion || window == nil {
            stopAnimation()
            setScroll(target)
        } else {
            animateScroll(to: target)
        }
    }

    private func updateHighlight(document: LyricsDocument, manager: NSLayoutManager) {
        let activeRange = document.absoluteReadingRange(readingRange)
        // Between ayahs the timed word is briefly unknown. While playing, keep the highlight on the
        // ayah's first line so the whole ayah never flashes bright and then jumps to one line.
        let startOfAyah = isPlaying && document.currentRange.length > 0
            ? NSRange(location: document.currentRange.location, length: 1) : nil
        guard let active = activeRange ?? startOfAyah else {
            if highlightedLine != nil {
                manager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: document.currentRange)
                highlightedLine = nil
                refreshMarkers(animated: false)
            }
            syncWordPointer(activeRange, manager: manager)
            return
        }
        let glyph = manager.glyphIndexForCharacter(at: active.location)
        var glyphRange = NSRange()
        _ = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &glyphRange)
        let characterRange = NSIntersectionRange(manager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil), document.currentRange)
        guard highlightedLine != characterRange else {
            syncWordPointer(activeRange, manager: manager)
            return
        }
        if highlightedLine != nil, !reduceMotion, window != nil {
            // Crossfade the ayah/line brightness; attributes alone cannot be interpolated.
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.28
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            documentView?.layer?.add(fade, forKey: "line-change")
        }
        highlightedLine = characterRange
        manager.addTemporaryAttribute(.foregroundColor,
                                      value: lyricAppearance.textColor.nsColor.withAlphaComponent(0.55),
                                      forCharacterRange: document.currentRange)
        manager.addTemporaryAttribute(.foregroundColor, value: lyricAppearance.textColor.nsColor, forCharacterRange: characterRange)
        refreshMarkers(animated: true)
        syncWordPointer(activeRange, manager: manager)
    }

    /// While playing, the timed word is unknown for a moment after each ayah starts. Keep the
    /// previous marker in place during that gap so it can travel to the new first word.
    private func syncWordPointer(_ range: NSRange?, manager: NSLayoutManager) {
        if range == nil, isPlaying, highlightedWord != nil { return }
        updateWordPointer(range, manager: manager)
    }

    private func clearWordPointer(manager: NSLayoutManager?) {
        highlightedWord = nil
        refreshMarkers(animated: false)
    }

    private func updateWordPointer(_ range: NSRange?, manager: NSLayoutManager) {
        guard highlightedWord != range else { return }
        highlightedWord = range
        refreshMarkers(animated: true)
    }

    // MARK: Animated highlight layers

    /// The word box, underline and line background live behind the text as plain layers,
    /// so their frames can glide between words and lines instead of jumping.
    private func installLayers() -> CALayer? {
        contentView.wantsLayer = true
        guard let host = contentView.layer else { return nil }
        if lineLayer.superlayer !== host {
            lineLayer.opacity = 0
            wordLayer.opacity = 0
            wordLayer.cornerRadius = 4
            wordLayer.addSublayer(underlineLayer)
            host.insertSublayer(lineLayer, at: 0)
            host.insertSublayer(wordLayer, above: lineLayer)
        }
        return host
    }

    private func firstLineRect(for range: NSRange) -> NSRect? {
        guard let view = documentView as? NSTextView, let manager = view.layoutManager,
              let container = view.textContainer, range.length > 0,
              NSMaxRange(range) <= (manager.textStorage?.length ?? 0) else { return nil }
        manager.ensureLayout(for: container)
        var first: NSRect?
        let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        manager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                        in: container) { rect, stop in
            first = rect
            stop.pointee = true
        }
        return first.map { $0.offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y) }
    }

    private func place(_ layer: CALayer, frame: NSRect?, animated: Bool) {
        let visible = layer.opacity > 0
        let duration = animated && !reduceMotion && window != nil && visible ? 0.24 : 0
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        if duration == 0 { CATransaction.setDisableActions(true) }
        if let frame {
            layer.frame = frame
            layer.opacity = 1
        } else {
            layer.opacity = 0
        }
        CATransaction.commit()
    }

    private func refreshMarkers(animated: Bool) {
        guard installLayers() != nil, let view = documentView as? NSTextView,
              let manager = view.layoutManager else { return }
        let text = lyricAppearance.textColor.nsColor
        wordLayer.backgroundColor = text.withAlphaComponent(0.18).cgColor
        underlineLayer.backgroundColor = text.cgColor
        lineLayer.backgroundColor = lyricAppearance.backgroundColor.nsColor
            .withAlphaComponent(lyricAppearance.backgroundOpacity).cgColor
        wordMarkerFrame = highlightedWord.flatMap { firstLineRect(for: $0) }
        place(wordLayer, frame: wordMarkerFrame, animated: animated)
        // The clip view's layer is flipped, which flips this sublayer's own coordinates too.
        let thickness: CGFloat = 2
        let height = wordMarkerFrame?.height ?? 0
        underlineLayer.frame = NSRect(x: 0, y: wordLayer.contentsAreFlipped() ? height - thickness : 0,
                                      width: wordMarkerFrame?.width ?? 0, height: thickness)
        var lineFrame: NSRect?
        if lyricAppearance.backgroundOpacity > 0, let line = highlightedLine, line.length > 0,
           line.location < (manager.textStorage?.length ?? 0) {
            let glyph = manager.glyphIndexForCharacter(at: line.location)
            lineFrame = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                .offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
        }
        lineBackgroundFrame = lineFrame
        place(lineLayer, frame: lineFrame, animated: animated)
    }

    private func boundedOffset(_ offset: CGFloat) -> CGFloat {
        min(max(0, (documentView?.frame.height ?? 0) - contentSize.height), max(0, offset))
    }

    private func setScroll(_ offset: CGFloat) {
        contentView.scroll(to: NSPoint(x: 0, y: boundedOffset(offset)))
        reflectScrolledClipView(contentView)
    }

    private func animateScroll(to target: CGFloat) {
        // Re-target from the current presentation position, never a queued animator.
        stopAnimation()
        animationFrom = contentView.bounds.minY
        animationTarget = target
        guard abs(animationFrom - target) > 0.5 else { setScroll(target); return }
        animationStart = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.animationTick() }
        scrollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func animationTick() {
        let progress = min(1, (CACurrentMediaTime() - animationStart) / animationDuration)
        // Smoothstep: zero velocity at both ends, with no overshoot.
        let eased = progress * progress * (3 - 2 * progress)
        setScroll(animationFrom + (animationTarget - animationFrom) * eased)
        if progress >= 1 { stopAnimation() }
    }

    override func scrollWheel(with event: NSEvent) {
        // Ignore manual scrolling without interrupting the recitation follower.
        // Mouse dragging remains handled by WindowDrag on the hosting ancestor.
    }

    func stopAnimation() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    deinit { scrollTimer?.invalidate() }
}
