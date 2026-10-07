import AppKit
import Combine
import SwiftUI

final class AyahPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isVisible = false
    let panel: AyahPanel
    private let store: PlayerStore
    private var subscriptions = Set<AnyCancellable>()
    private var updatingFrame = false
    private var hostingView: NSHostingView<PanelView>?
    private var windowDrag: WindowDrag?

    init(store: PlayerStore) {
        self.store = store
        panel = AyahPanel(
            contentRect: NSRect(x: 0, y: 0, width: PanelLayout.width, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        super.init()
        panel.title = "Floating Ayah"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.isMovableByWindowBackground = false

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let saved = UserDefaults.standard.dictionary(forKey: "panelOrigin")
        let originX = saved?["x"] as? Double ?? screen.maxX - PanelLayout.width - 32
        let originY = saved?["y"] as? Double ?? screen.maxY - 260
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        updateLayout()
        store.$position.combineLatest(store.$fontSize, store.$fontName, store.$appearance)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLayout() }
            .store(in: &subscriptions)
        store.$isSurahPause
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLayout() }
            .store(in: &subscriptions)
        store.$isBasmalah
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLayout() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLayout() }
            .store(in: &subscriptions)
    }

    func show() {
        updateLayout()
        panel.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel.orderOut(nil)
        isVisible = false
    }

    func toggle() { isVisible ? hide() : show() }

    private func updateLayout() {
        guard !updatingFrame else { return }
        updatingFrame = true
        defer { updatingFrame = false }
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let layout = PanelLayout(text: store.displayText, fontSize: store.fontSize,
                                 availableHeight: screen.height - 24, fontName: store.fontName,
                                 width: min(store.appearance.panelWidth, screen.width - 24),
                                 spacing: store.appearance.lineSpacing,
                                 lines: store.appearance.visibleLines)
        let top = min(panel.frame.maxY, screen.maxY - 12)
        let originX = min(max(panel.frame.minX, screen.minX + 12), screen.maxX - layout.panelWidth - 12)
        let originY = max(screen.minY + 12, top - layout.height)
        let frame = NSRect(x: originX, y: originY, width: layout.panelWidth, height: layout.height)
        panel.setFrame(frame, display: true)
        let view = PanelView(store: store, layout: layout, hide: { [weak self] in self?.hide() })
        if let hostingView {
            hostingView.rootView = view
            hostingView.frame = NSRect(origin: .zero, size: frame.size)
        } else {
            let hosting = NSHostingView(rootView: view)
            // Let the controller own sizing; SwiftUI must never widen the window.
            hosting.sizingOptions = []
            hosting.frame = NSRect(origin: .zero, size: frame.size)
            panel.contentView = hosting
            hostingView = hosting
            windowDrag = WindowDrag(view: hosting)
        }
        panel.minSize = frame.size
        panel.maxSize = frame.size
    }

    func windowDidMove(_ notification: Notification) {
        guard !updatingFrame else { return }
        updateLayout()
        UserDefaults.standard.set(["x": panel.frame.minX, "y": panel.frame.minY], forKey: "panelOrigin")
    }
}
