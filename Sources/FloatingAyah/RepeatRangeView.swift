import SwiftUI

/// Loops a range of ayahs in the current surah, for memorizing. It lives in the menu rather than
/// on the panel because it needs two numbers.
struct RepeatRangeView: View {
    @ObservedObject var store: PlayerStore
    let onStart: () -> Void
    @State private var from = ""
    @State private var to = ""
    @State private var message: String?

    private var isRepeating: Bool { store.playbackMode == .repeatRange }
    private var count: Int { store.surah.ayahs.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Ayahs").foregroundStyle(.secondary)
                field($from, label: "First ayah to repeat")
                Text("–").foregroundStyle(.secondary)
                field($to, label: "Last ayah to repeat")
                Button("Repeat", action: start).disabled(from.isEmpty || to.isEmpty)
                if isRepeating {
                    Button("Stop", action: store.stopRepeatingRange)
                }
            }
            Group {
                if let message {
                    Text(message).foregroundStyle(.red)
                } else if isRepeating {
                    Text("\(store.playbackModeTitle) of \(store.surah.name)").foregroundStyle(.secondary)
                } else {
                    Text("Loops ayahs of \(store.surah.name) (1–\(count))").foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 11))
        }
        // Refill when the surah changes, from the last range when it was in this surah.
        .task(id: store.position.surah) { fill() }
    }

    private func field(_ text: Binding<String>, label: String) -> some View {
        TextField("", text: text)
            .textFieldStyle(.roundedBorder)
            .frame(width: 52)
            .onSubmit(start)
            .accessibilityLabel(label)
    }

    private func fill() {
        message = nil
        if let range = store.repeatRange, range.surah == store.position.surah {
            from = String(range.first + 1)
            to = String(range.last + 1)
        } else {
            from = String(store.ayah.number)
            to = ""
        }
    }

    private func start() {
        guard let a = Int(from.trimmingCharacters(in: .whitespaces)),
              let b = Int(to.trimmingCharacters(in: .whitespaces)),
              (1...count).contains(a), (1...count).contains(b) else {
            message = "Enter ayahs from 1 to \(count)"
            return
        }
        let (first, last) = (min(a, b), max(a, b))
        let surah = store.position.surah
        if let missing = (first...last).first(where: { !store.isAvailable(AyahPosition(surah: surah, ayah: $0 - 1)) }) {
            message = "Ayah \(missing) is not recorded by \(store.reciter.name)"
            return
        }
        message = nil
        from = String(first)
        to = String(last)
        store.repeatAyahs(from: first - 1, to: last - 1)
        store.play()
        onStart()
    }
}
