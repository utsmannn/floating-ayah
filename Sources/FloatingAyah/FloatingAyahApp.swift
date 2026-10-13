import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct FloatingAyahApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store: PlayerStore
    @StateObject private var panel: PanelController
    @StateObject private var updates: UpdateChecker
    private let mediaControls: MediaControls
    private static let menuIcon: NSImage = {
        let image = Quran.resourceBundle.url(forResource: "MenuBarIcon", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "book.closed", accessibilityDescription: "Floating Ayah")!
        image.size = NSSize(width: 22, height: 13)
        image.isTemplate = true
        return image
    }()
    /// The menu icon with a dot in its top-right corner, kept as a template like the plain icon.
    private static let menuIconWithBadge: NSImage = {
        let size = menuIcon.size
        let image = NSImage(size: NSSize(width: size.width + 4, height: size.height), flipped: false) { _ in
            menuIcon.draw(in: NSRect(origin: .zero, size: size))
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: size.width - 1, y: size.height - 5, width: 5, height: 5)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

    init() {
        do {
            let player = PlayerStore(quran: try Quran.load())
            let controller = PanelController(store: player)
            mediaControls = MediaControls(store: player)
            _store = StateObject(wrappedValue: player)
            _panel = StateObject(wrappedValue: controller)
            // Started here, not from the menu, whose content is only built when first opened.
            let checker = UpdateChecker()
            checker.startAutomaticChecks()
            _updates = StateObject(wrappedValue: checker)
            controller.show()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Unable to load Quran text"
            alert.informativeText = "Rebuild the app to include the bundled Quran resources."
            alert.runModal()
            exit(1)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(store: store, panel: panel, updates: updates)
        } label: {
            Image(nsImage: updates.hasUpdate ? Self.menuIconWithBadge : Self.menuIcon)
                .accessibilityLabel(updates.hasUpdate ? "Floating Ayah, update available" : "Floating Ayah")
        }
        .menuBarExtraStyle(.window)
    }
}
