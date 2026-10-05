import SwiftUI

struct ReciterView: View {
    @ObservedObject var store: PlayerStore
    @ObservedObject var offline: OfflineAudio
    @ObservedObject var sample: ReciterSample

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Same right-aligned dropdown style as the surah and font pickers.
            HStack {
                Text("Reciter")
                Spacer()
                Menu {
                    ForEach(Reciter.allCases) { reciter in
                        Button {
                            store.selectReciter(reciter)
                        } label: {
                            if reciter == store.reciter {
                                Label(reciter.name, systemImage: "checkmark")
                            } else {
                                Text(reciter.name)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(store.reciter.name).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 9))
                    }
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Reciter: \(store.reciter.name)")
            }
            .disabled(offline.isDownloading)
            HStack {
                Text(store.reciter.details).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                if sample.isLoading { ProgressView().controlSize(.small) }
                Button(action: store.toggleSample) {
                    Label(sample.isPlaying ? "Stop sample" : "Play sample",
                          systemImage: sample.isPlaying ? "stop.fill" : "speaker.wave.2")
                }
                .help("Preview Al-Fatihah, ayah 2. Your current ayah will not change.")
            }
            if offline.isDownloading {
                Text("Cancel or finish the download before changing reciters.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let error = sample.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}
