import SwiftUI

struct OfflineAudioView: View {
    @ObservedObject var offline: OfflineAudio
    let quran: Quran
    private var saved: Int { offline.savedAyahs }
    private var ayahCount: Int { quran.surahs.reduce(0) { $0 + $1.ayahs.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Offline audio", systemImage: "arrow.down.circle")
                Spacer()
                Text("\(saved)/\(ayahCount) ayahs")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text("\(offline.reciter.name) · \(offline.reciter.bitrate) kbps")
                .foregroundStyle(.secondary)
            Text("Downloaded: \(AudioSizes.formatted(offline.savedBytes))")
                .foregroundStyle(.secondary)
            if let totalBytes = offline.estimatedTotalBytes {
                Text("Full download ≈ \(AudioSizes.formatted(totalBytes)) · EveryAyah estimate")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Total size unavailable")
                    .foregroundStyle(.secondary)
            }
            if let number = offline.downloadingSurah {
                let name = quran.surahs.first(where: { $0.number == number })?.name ?? "Surah"
                Text("Downloading \(name) · \(offline.completed)/\(offline.total)")
                    .foregroundStyle(.secondary)
                HStack {
                    ProgressView(value: offline.progress).frame(maxWidth: .infinity)
                    Button("Cancel", action: offline.cancel)
                }
            } else if saved == ayahCount {
                Label("The entire Quran is ready to play offline", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                Button(saved > 0 ? "Resume Quran download" : "Download entire Quran") {
                    offline.downloadAll(quran: quran)
                }
                Text("114 surahs for this reciter. Requires internet and disk space. You can cancel and resume later.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = offline.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12))
    }
}
