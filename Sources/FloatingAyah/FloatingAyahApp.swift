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
    private let mediaControls: MediaControls
    private static let menuIcon: NSImage = {
        let image = Quran.resourceBundle.url(forResource: "MenuBarIcon", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "book.closed", accessibilityDescription: "Floating Ayah")!
        image.size = NSSize(width: 22, height: 13)
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
            MenuView(store: store, panel: panel)
        } label: {
            Image(nsImage: Self.menuIcon)
                .accessibilityLabel("Floating Ayah")
        }
        .menuBarExtraStyle(.window)
    }
}
