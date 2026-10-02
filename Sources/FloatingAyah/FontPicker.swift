import AppKit
import SwiftUI

/// A real dropdown popover: native Picker menus discard rich SwiftUI row previews.
struct FontPicker: View {
    @Binding var selection: String
    @State private var showing = false
    private let sample = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"

    var body: some View {
        HStack {
            Text("Arabic font")
            Spacer()
            Button { showing.toggle() } label: {
                HStack {
                    Text(ArabicFonts.displayName(selection)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9))
                }
            }
            .popover(isPresented: $showing, arrowEdge: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(ArabicFonts.available, id: \.self) { name in
                                Button {
                                    selection = name
                                    showing = false
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(ArabicFonts.displayName(name)).font(.system(size: 12))
                                            Spacer()
                                            if name == selection { Image(systemName: "checkmark") }
                                        }
                                        Text(sample)
                                            .font(Font(ArabicFonts.font(name: name, size: 25)))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .environment(\.layoutDirection, .rightToLeft)
                                            .padding(.vertical, 6)
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(name == selection ? Color.accentColor.opacity(0.12) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(name)
                                .accessibilityLabel(ArabicFonts.displayName(name))
                            }
                        }
                        .padding(8)
                    }
                    .onAppear { proxy.scrollTo(selection, anchor: .center) }
                }
                .frame(width: 320, height: 380)
            }
        }
    }
}
