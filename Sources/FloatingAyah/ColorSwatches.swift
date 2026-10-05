import SwiftUI

/// Five fixed choices per setting. A system color panel is heavy for a menu-bar window.
struct ColorSwatch: Identifiable {
    let name: String
    let color: LyricColor
    var id: String { name }

    static let text: [ColorSwatch] = [
        ColorSwatch(name: "White", color: .white),
        ColorSwatch(name: "Cream", color: LyricColor(red: 0.96, green: 0.90, blue: 0.78)),
        ColorSwatch(name: "Gold", color: LyricColor(red: 0.95, green: 0.76, blue: 0.31)),
        ColorSwatch(name: "Mint", color: LyricColor(red: 0.56, green: 0.89, blue: 0.69)),
        ColorSwatch(name: "Sky", color: LyricColor(red: 0.56, green: 0.79, blue: 0.96))
    ]

    static let dark: [ColorSwatch] = [
        ColorSwatch(name: "Black", color: .black),
        ColorSwatch(name: "Navy", color: LyricColor(red: 0.04, green: 0.15, blue: 0.27)),
        ColorSwatch(name: "Forest", color: LyricColor(red: 0.07, green: 0.22, blue: 0.16)),
        ColorSwatch(name: "Plum", color: LyricColor(red: 0.23, green: 0.12, blue: 0.29)),
        ColorSwatch(name: "Brown", color: LyricColor(red: 0.24, green: 0.16, blue: 0.12))
    ]

    func matches(_ other: LyricColor) -> Bool {
        abs(color.red - other.red) < 0.02 && abs(color.green - other.green) < 0.02 && abs(color.blue - other.blue) < 0.02
    }
}

struct ColorSwatchRow: View {
    let title: String
    let swatches: [ColorSwatch]
    @Binding var selection: LyricColor

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 8) {
                ForEach(swatches) { swatch in
                    let selected = swatch.matches(selection)
                    Button { selection = swatch.color } label: {
                        Circle()
                            .fill(swatch.color.color)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: selected ? 2.5 : 0).padding(-3))
                    }
                    .buttonStyle(.plain)
                    .help(swatch.name)
                    .accessibilityLabel("\(title): \(swatch.name)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}
