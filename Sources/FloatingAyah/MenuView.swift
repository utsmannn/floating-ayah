import AppKit
import SwiftUI

struct MenuView: View {
    @ObservedObject var store: PlayerStore
    @ObservedObject var panel: PanelController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                nowPlaying
                section("Go to") {
                    SurahPicker(store: store, onSelect: panel.show)
                    AyahInput(store: store, onSelect: panel.show)
                }
                section("Reciter") {
                    ReciterView(store: store, offline: store.offline, sample: store.sample)
                }
                section("Appearance") {
                    AppearanceSettingsView(store: store)
                }
                section("Offline audio") {
                    OfflineAudioView(offline: store.offline, quran: store.quran)
                }
                if let error = store.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 12))
                        Button("Retry", action: store.retry)
                    }
                }
                footer
            }
            .padding(20)
        }
        .frame(width: 360, height: 600)
        .environment(\.locale, Locale(identifier: "en_US"))
    }

    private var header: some View {
        HStack {
            Text("Floating Ayah").font(.headline)
            Spacer()
            Button(action: panel.toggle) {
                Image(systemName: panel.isVisible ? "rectangle.slash" : "rectangle")
            }
            .buttonStyle(.borderless)
            .help(panel.isVisible ? "Hide panel" : "Show panel")
            .accessibilityLabel(panel.isVisible ? "Hide panel" : "Show panel")
        }
    }

    private var nowPlaying: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(store.surah.arabicName)
                    .font(Font(ArabicFonts.font(name: ArabicFonts.quranName, size: 24)))
                Text("\(store.surah.number). \(store.surah.name)").font(.system(size: 13, weight: .semibold))
                Text(store.isBasmalah ? "Basmalah" : "Ayah \(store.ayah.number) of \(store.surah.ayahs.count)")
                    .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(spacing: 14) {
                transport("backward.fill", store.previousSurahLabel, enabled: store.canGoPreviousSurah, action: store.previousSurah)
                transport("backward.end.fill", store.previousAyahLabel, enabled: store.canGoPrevious, action: store.previous)
                Button {
                    panel.show()
                    store.togglePlayback()
                } label: {
                    Image(systemName: store.actionIcon).frame(width: 34, height: 26)
                }
                .buttonStyle(.borderedProminent)
                .help(store.actionLabel)
                .accessibilityLabel(store.actionLabel)
                transport("forward.end.fill", "Next ayah", enabled: store.canGoNext, action: store.next)
                transport("forward.fill", "Next surah", enabled: store.canGoNextSurah, action: store.nextSurah)
            }
            Picker("Playback mode", selection: $store.playbackMode) {
                ForEach(PlaybackMode.allCases) { mode in
                    Image(systemName: mode.symbol).help(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Playback mode")
            Text(store.playbackMode.title).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func transport(_ icon: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).frame(width: 24, height: 24) }
            .buttonStyle(.borderless)
            .disabled(!enabled)
            .help(label)
            .accessibilityLabel(label)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            content()
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(store.reciter.name) · \(store.reciter.bitrate) kbps")
                    Text("Audio: EveryAyah · Text: Al Quran Cloud")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.borderless)
            }
        }
    }
}
