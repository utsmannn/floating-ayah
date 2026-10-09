import SwiftUI

struct PanelLayout {
    static let width: CGFloat = 420
    static let textWidth: CGFloat = width
    static let chromeHeight: CGFloat = 0
    let panelWidth: CGFloat
    var contentWidth: CGFloat { panelWidth }
    let textHeight: CGFloat
    let viewportHeight: CGFloat
    var height: CGFloat { viewportHeight }
    var needsScroll: Bool { textHeight + 12 > viewportHeight }

    init(text: String, fontSize: Double, availableHeight: CGFloat,
         fontName: String = ArabicFonts.defaultName, width: Double = 420, spacing: Double = 6,
         lines: Int = LyricAppearance.defaultLines) {
        panelWidth = CGFloat(min(800, max(280, width)))
        textHeight = ArabicTypography.height(for: text, size: fontSize, width: panelWidth, fontName: fontName, spacing: spacing)
        // Chrome overlays the faded edges; only the lyric lines set height.
        let rowHeight = ArabicTypography.lineHeight(size: fontSize, spacing: spacing)
        viewportHeight = min(rowHeight * CGFloat(LyricAppearance.clampedLines(lines)), max(60, availableHeight))
    }
}

struct PanelView: View {
    @ObservedObject var store: PlayerStore
    let layout: PanelLayout
    let hide: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsControls: Bool { hovering || store.errorMessage != nil }

    var body: some View {
        LyricsText(text: store.displayText,
                   surahIndex: store.position.surah, isOpeningPause: store.isSurahPause,
                   previousText: store.previousAyahText, nextText: store.nextAyahText,
                   currentNumber: store.displayNumber,
                   previousNumber: store.previousAyahNumber, nextNumber: store.nextAyahNumber,
                   surahBefore: store.appearance.continuousText ? store.continuousContext?.before : nil,
                   surahAfter: store.appearance.continuousText ? store.continuousContext?.after : nil,
                   isPlaying: store.isPlaying,
                   fontSize: store.fontSize, fontName: store.fontName, appearance: store.appearance,
                   readingRange: store.readingRange,
                   onClick: store.togglePlayback)
            .frame(width: layout.contentWidth, height: layout.viewportHeight)
            .mask { edgeFade }
            .overlay(alignment: .top) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.displayTitle)
                            .font(.system(size: 12, weight: .semibold))
                        Text(store.statusText)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help("Drag anywhere to move the window")

                    if store.isBuffering {
                        ProgressView().controlSize(.small)
                    }
                    Button(action: hide) { Image(systemName: "minus").frame(width: 28, height: 28) }
                        .buttonStyle(.borderless)
                        .help("Hide the panel without stopping audio")
                        .accessibilityLabel("Hide panel")
                }
                .frame(height: 36)
                .padding(.horizontal, 8)
                .background(Color.black.opacity(0.4))
                .opacity(showsControls ? 1 : 0)
                .allowsHitTesting(showsControls)
                .accessibilityHidden(!showsControls)
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 4) {
                    control(store.playbackMode.symbol,
                            label: "Playback mode: \(store.playbackMode.title). Click to change.",
                            action: store.cyclePlaybackMode)
                        .foregroundStyle(store.playbackMode == .continuous ? Color.white : Color.accentColor)
                    Spacer(minLength: 0)
                    control("backward.fill", label: store.previousSurahLabel, action: store.previousSurah)
                        .disabled(!store.canGoPreviousSurah)
                    control("backward.end.fill", label: store.previousAyahLabel, action: store.previous)
                        .disabled(!store.canGoPrevious)
                    control(store.actionIcon, label: store.actionLabel, action: store.togglePlayback)
                        .keyboardShortcut(.space, modifiers: [])
                    control("forward.end.fill", label: "Next ayah", action: store.next)
                        .disabled(!store.canGoNext)
                    control("forward.fill", label: "Next surah", action: store.nextSurah)
                        .disabled(!store.canGoNextSurah)
                    Spacer(minLength: 0)
                    if store.errorMessage != nil {
                        control("arrow.clockwise", label: "Retry audio", action: store.retry)
                    } else {
                        Text(store.isBasmalah ? "Basmalah" : "\(store.ayah.number)/\(store.surah.ayahs.count)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(minWidth: 34)
                    }
                }
                .frame(height: 32)
                .padding(.horizontal, 8)
                .background(Color.black.opacity(0.4))
                .opacity(showsControls ? 1 : 0)
                .allowsHitTesting(showsControls)
                .accessibilityHidden(!showsControls)
            }
            .frame(width: layout.panelWidth, height: layout.height)
            .contentShape(Rectangle())
            .foregroundStyle(.white)
            .background(Color.black.opacity(showsControls ? 0.2 : 0))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onHover { value in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { hovering = value }
            }
            .help(store.errorMessage ?? "Click the ayah to play or pause. Drag anywhere to move the window.")
            .environment(\.locale, Locale(identifier: "en_US"))
    }

    /// Fades the first and last row. With one row there is nothing to fade into, and two rows
    /// would lose their text, so the fade is shorter the fewer rows are shown.
    private var edgeFade: some View {
        let lines = LyricAppearance.clampedLines(store.appearance.visibleLines)
        let edge: Double = lines <= 1 ? 0 : (lines == 2 ? 0.12 : min(0.3, 1.0 / Double(lines)))
        return LinearGradient(stops: [
            .init(color: .black.opacity(lines <= 1 ? 1 : 0), location: 0),
            .init(color: .black.opacity(lines <= 2 ? 0.85 : 0.65), location: edge * 0.55),
            .init(color: .black, location: edge),
            .init(color: .black, location: 1 - edge),
            .init(color: .black.opacity(lines <= 2 ? 0.85 : 0.65), location: 1 - edge * 0.55),
            .init(color: .black.opacity(lines <= 1 ? 1 : 0), location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    private func control(_ image: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(label)
    }
}
