import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var store: PlayerStore
    @State private var expanded = false

    var body: some View {
        DisclosureGroup("Ayah appearance", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                ColorPicker("Text color", selection: Binding(
                    get: { store.appearance.textColor.color },
                    set: { store.appearance.textColor = LyricColor($0) }
                ), supportsOpacity: false)
                Toggle("Text shadow", isOn: $store.appearance.shadowEnabled)
                    .toggleStyle(.checkbox)
                Group {
                    ColorPicker("Shadow color", selection: Binding(
                        get: { store.appearance.shadowColor.color },
                        set: { store.appearance.shadowColor = LyricColor($0) }
                    ), supportsOpacity: false)
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
            .padding(.top, 10)
        }
        .font(.system(size: 12))
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
