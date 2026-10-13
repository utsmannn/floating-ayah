import SwiftUI

/// A dropdown of all surahs with a search field inside it. Typing narrows the list;
/// Return picks the first match.
struct SurahPicker: View {
    @ObservedObject var store: PlayerStore
    let onSelect: () -> Void
    @State private var showing = false
    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [Surah] {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? store.quran.surahs
            : SurahSearch.matches(query, in: store.quran.surahs, limit: store.quran.surahs.count)
    }

    var body: some View {
        HStack {
            Text("Surah")
            Spacer()
            Button { showing.toggle() } label: {
                HStack {
                    Text("\(store.surah.number). \(store.surah.name)").lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9))
                }
            }
            .accessibilityLabel("Surah: \(store.surah.name)")
            .popover(isPresented: $showing, arrowEdge: .bottom) { list }
        }
    }

    private var list: some View {
        VStack(spacing: 8) {
            TextField("Search name or number", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { if let first = results.first { choose(first) } }
                .accessibilityLabel("Search surah")
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if results.isEmpty {
                            Text("No matching surah").font(.system(size: 11)).foregroundStyle(.secondary)
                                .padding(.top, 12)
                        }
                        ForEach(results) { surah in
                            let selected = surah.number == store.surah.number
                            let recorded = store.availableCount(inSurah: surah.number - 1)
                            Button { choose(surah) } label: {
                                HStack {
                                    Text("\(surah.number). \(surah.name)")
                                    Spacer()
                                    Text(recorded == surah.ayahs.count ? "\(surah.ayahs.count)" : "\(recorded)/\(surah.ayahs.count)")
                                        .foregroundStyle(.secondary).monospacedDigit()
                                    if selected { Image(systemName: "checkmark") }
                                }
                                .foregroundStyle(.primary)
                                .padding(.vertical, 5).padding(.horizontal, 8)
                                .background(selected ? Color.accentColor.opacity(0.14) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(recorded == 0)
                            .opacity(recorded == 0 ? 0.4 : 1)
                            .help(recorded == 0 ? "Not recorded by \(store.reciter.name)" : "")
                            .id(surah.number)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(store.surah.number, anchor: .center) }
            }
        }
        .padding(10)
        .frame(width: 280, height: 360)
        .onAppear {
            query = ""
            DispatchQueue.main.async { focused = true }
        }
    }

    private func choose(_ surah: Surah) {
        guard store.open(surah: surah.number - 1) else { return }
        showing = false
        onSelect()
    }
}

struct AyahInput: View {
    @ObservedObject var store: PlayerStore
    let onSelect: () -> Void
    @State private var text = ""
    @State private var invalid = false
    @State private var unrecorded = false

    var body: some View {
        HStack(spacing: 8) {
            Text("Ayah").foregroundStyle(.secondary)
            TextField("1–\(store.surah.ayahs.count)", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .onSubmit(commit)
                .accessibilityLabel("Ayah number")
            Button("Go", action: commit).disabled(text.isEmpty)
            if invalid {
                Text("Enter 1–\(store.surah.ayahs.count)").font(.system(size: 11)).foregroundStyle(.red)
            } else if unrecorded {
                Text("Not recorded").font(.system(size: 11)).foregroundStyle(.red)
            }
        }
    }

    private func commit() {
        guard let number = Int(text.trimmingCharacters(in: .whitespaces)),
              (1...store.surah.ayahs.count).contains(number) else { invalid = true; unrecorded = false; return }
        invalid = false
        unrecorded = !store.isAvailable(AyahPosition(surah: store.position.surah, ayah: number - 1))
        guard !unrecorded else { return }
        store.select(surah: store.position.surah, ayah: number - 1)
        text = ""
        onSelect()
    }
}
