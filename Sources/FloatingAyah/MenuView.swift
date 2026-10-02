import AppKit
import SwiftUI

struct MenuView: View {
    @ObservedObject var store: PlayerStore
    @ObservedObject var panel: PanelController

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
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

            ReciterView(store: store, offline: store.offline, sample: store.sample)

            VStack(alignment: .leading, spacing: 10) {
                Picker("Surah", selection: Binding(
                    get: { store.position.surah },
                    set: { store.select(surah: $0); panel.show() }
                )) {
                    ForEach(Array(store.quran.surahs.enumerated()), id: \.element.id) { index, surah in
                        Text("\(surah.number). \(surah.name)").tag(index)
                    }
                }
                Stepper(value: Binding(
                    get: { store.position.ayah + 1 },
                    set: { store.select(surah: store.position.surah, ayah: $0 - 1); panel.show() }
                ), in: 1...store.surah.ayahs.count) {
                    Text("Ayah \(store.ayah.number) of \(store.surah.ayahs.count)")
                        .font(.system(size: 12))
                        .monospacedDigit()
                }
            }

            HStack(spacing: 20) {
                Button(action: store.previous) { Image(systemName: "backward.end.fill") }
                    .disabled(!store.canGoPrevious)
                    .help("Previous ayah")
                    .accessibilityLabel("Previous ayah")
                Button {
                    panel.show()
                    store.togglePlayback()
                } label: {
                    Label(store.actionLabel, systemImage: store.actionIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(action: store.next) { Image(systemName: "forward.end.fill") }
                    .disabled(!store.canGoNext)
                    .help("Next ayah")
                    .accessibilityLabel("Next ayah")
            }
            Picker("Playback mode", selection: $store.playbackMode) {
                ForEach(PlaybackMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                FontPicker(selection: $store.fontName)
                HStack {
                    Text("Text size")
                    Spacer()
                    Text("\(Int(store.fontSize)) pt").foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(value: $store.fontSize, in: 22...42, step: 1)
                    .accessibilityLabel("Arabic text size")
            }
            .font(.system(size: 12))

            AppearanceSettingsView(store: store)

            OfflineAudioView(offline: store.offline, quran: store.quran)

            if let error = store.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                    Button("Retry", action: store.retry)
                }
            }

            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(store.reciter.name) · \(store.reciter.bitrate) kbps")
                    Text("Audio: EveryAyah · Text: Al Quran Cloud")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
            }
        }
        .padding(20)
        }
        .frame(width: 360, height: 580)
        .environment(\.locale, Locale(identifier: "en_US"))
    }
}
