// Hallmark · native utility panel · tone: quiet · platform semantic colors
// Pre-emit critique: Philosophy 5 · Hierarchy 4 · Execution 4 · Specificity 5 · Restraint 5 · Variety 4
import SwiftUI

struct PanelLayout {
    static let width: CGFloat = 420
    static let textWidth: CGFloat = width - 40 - 16 // Reserve space for a scrollbar.
    static let chromeHeight: CGFloat = 140
    let panelWidth: CGFloat
    var contentWidth: CGFloat { panelWidth - 56 }
    let textHeight: CGFloat
    let viewportHeight: CGFloat
    var height: CGFloat { viewportHeight + Self.chromeHeight }
    var needsScroll: Bool { textHeight + 12 > viewportHeight }

    init(text: String, fontSize: Double, availableHeight: CGFloat,
         fontName: String = ArabicFonts.defaultName, width: Double = 420, spacing: Double = 6) {
        panelWidth = CGFloat(min(800, max(280, width)))
        textHeight = ArabicTypography.height(for: text, size: fontSize, width: panelWidth - 56, fontName: fontName, spacing: spacing)
        // Share the compact baseline rhythm with TextKit, regardless of font.
        viewportHeight = min(ArabicTypography.lineHeight(size: fontSize, spacing: spacing) * 3,
                             max(60, availableHeight - Self.chromeHeight))
    }
}

struct PanelView: View {
    @ObservedObject var store: PlayerStore
    let layout: PanelLayout
    let hide: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
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
            .opacity(hovering || store.errorMessage != nil ? 1 : 0)
            .allowsHitTesting(hovering || store.errorMessage != nil)

            LyricsText(text: store.displayText,
                       surahIndex: store.position.surah, isOpeningPause: store.isSurahPause,
                       previousText: store.previousAyahText, nextText: store.nextAyahText,
                       currentNumber: store.displayNumber,
                       previousNumber: store.previousAyahNumber, nextNumber: store.nextAyahNumber,
                       fontSize: store.fontSize, fontName: store.fontName, appearance: store.appearance,
                       readingRange: store.readingRange, reduceMotion: reduceMotion,
                       onClick: store.togglePlayback)
                .frame(width: layout.contentWidth, height: layout.viewportHeight)
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.65), location: 0.16),
                        .init(color: .black, location: 0.3),
                        .init(color: .black, location: 0.7),
                        .init(color: .black.opacity(0.65), location: 0.84),
                        .init(color: .clear, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }

            HStack(spacing: 14) {
                control("repeat.1", label: store.repeatsAyah ? "Turn off ayah repeat" : "Repeat current ayah", action: { store.repeatsAyah.toggle() })
                    .foregroundStyle(store.repeatsAyah ? Color.accentColor : Color.white)
                Spacer(minLength: 0)
                control("backward.end.fill", label: "Previous ayah", action: store.previous)
                    .disabled(!store.canGoPrevious)
                control(store.actionIcon, label: store.actionLabel, action: store.togglePlayback)
                    .keyboardShortcut(.space, modifiers: [])
                control("forward.end.fill", label: "Next ayah", action: store.next)
                    .disabled(!store.canGoNext)
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
            // Keep the row's space reserved so hover never resizes the panel.
            .opacity(hovering || store.errorMessage != nil ? 1 : 0)
            .allowsHitTesting(hovering || store.errorMessage != nil)
            .accessibilityHidden(false)
        }
        .padding(20)
        .frame(width: layout.panelWidth, height: layout.height)
        .foregroundStyle(.white)
        .background(Color.black.opacity(hovering || store.errorMessage != nil ? 0.35 : 0))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onHover { value in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { hovering = value }
        }
        .help(store.errorMessage ?? "Click the ayah to play or pause. Drag anywhere to move the window.")
        .environment(\.locale, Locale(identifier: "en_US"))
    }

    private func control(_ image: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(label)
    }
}
