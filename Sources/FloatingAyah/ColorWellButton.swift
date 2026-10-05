import AppKit
import SwiftUI

/// The menu-bar window dismisses when SwiftUI's ColorPicker opens its popover.
/// The shared AppKit color panel is a separate window, so it stays open while
/// colors update live.
@MainActor
final class ColorPanelBridge: NSObject {
    static let shared = ColorPanelBridge()
    private var handler: ((NSColor) -> Void)?

    func open(color: NSColor, onChange: @escaping (NSColor) -> Void) {
        handler = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = color
        panel.setTarget(self)
        panel.setAction(#selector(changed(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
    }

    @objc private func changed(_ sender: NSColorPanel) { handler?(sender.color) }
}

struct ColorWellButton: View {
    let title: String
    @Binding var color: LyricColor

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                ColorPanelBridge.shared.open(color: color.nsColor) { color = LyricColor(Color(nsColor: $0)) }
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.color)
                    .frame(width: 34, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .help("Choose \(title.lowercased())")
            .accessibilityLabel(title)
        }
    }
}
