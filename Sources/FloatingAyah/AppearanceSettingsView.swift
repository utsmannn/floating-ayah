import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var store: PlayerStore
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The whole row is the button; DisclosureGroup only reacts to its tiny chevron.
            Button {
                withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 12)
                    Text("Customize ayah text")
                    Spacer()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Customize ayah text")
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityAddTraits(.isButton)
            if expanded { controls }
        }
        .font(.system(size: 12))
    }

    private var controls: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                FontPicker(selection: $store.fontName)
                setting("Font size", value: $store.fontSize, range: 22...42, unit: "pt")
                Stepper(value: $store.appearance.visibleLines, in: LyricAppearance.minLines...LyricAppearance.maxLines) {
                    Text("Lines shown: \(store.appearance.visibleLines)").monospacedDigit()
                }
                .accessibilityLabel("Lines shown")
                Toggle("Continuous text", isOn: $store.appearance.continuousText)
                    .toggleStyle(.checkbox)
                    .help("Let adjacent ayahs and basmalah flow together without forced line breaks")
                ColorSwatchRow(title: "Text color", swatches: ColorSwatch.text, selection: $store.appearance.textColor)
                ColorSwatchRow(title: "Line background", swatches: ColorSwatch.dark, selection: $store.appearance.backgroundColor)
                HStack {
                    Text("Line background opacity")
                    Spacer()
                    Text("\(Int((store.appearance.backgroundOpacity * 100).rounded()))%")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(value: $store.appearance.backgroundOpacity, in: 0...1, step: 0.05)
                    .accessibilityLabel("Line background opacity")
                Toggle("Text shadow", isOn: $store.appearance.shadowEnabled)
                    .toggleStyle(.checkbox)
                Group {
                    ColorSwatchRow(title: "Shadow color", swatches: ColorSwatch.dark, selection: $store.appearance.shadowColor)
                    setting("Shadow depth", value: $store.appearance.shadowDepth, range: 0...16, unit: "pt")
                    setting("Blur", value: $store.appearance.shadowBlur, range: 0...20, unit: "pt")
                    HStack {
                        Text("Shadow opacity")
                        Spacer()
                        Text("\(Int(store.appearance.shadowOpacity * 100))%")
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                    Slider(value: $store.appearance.shadowOpacity, in: 0...1, step: 0.05)
                        .accessibilityLabel("Shadow opacity")
                }
                .disabled(!store.appearance.shadowEnabled)
                setting("Line spacing", value: $store.appearance.lineSpacing, range: 0...24, unit: "pt")
                HStack {
                    Text("Ayah number size")
                    Spacer()
                    Text("\(Int((store.appearance.ayahNumberScale * 100).rounded()))%")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(value: $store.appearance.ayahNumberScale, in: 0.6...1.2, step: 0.05)
                    .accessibilityLabel("Ayah number size")
                setting("Panel width", value: $store.appearance.panelWidth, range: 280...800, unit: "pt", step: 10)
                Text("The panel keeps your chosen width. Text wraps automatically.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
    }

    private func setting(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                         unit: String, step: Double = 1) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)").foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range, step: step).accessibilityLabel(title)
        }
    }
}
