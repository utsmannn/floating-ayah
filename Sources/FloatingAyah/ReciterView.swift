import SwiftUI

struct ReciterView: View {
    @ObservedObject var store: PlayerStore
    @ObservedObject var offline: OfflineAudio
    @ObservedObject var sample: ReciterSample

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Reciter", selection: Binding(get: { store.reciter }, set: store.selectReciter)) {
                ForEach(Reciter.allCases) { reciter in Text(reciter.name).tag(reciter) }
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
