import AppKit
import SwiftUI

/// Ouvre les fenêtres de l'app (guide, réglages) depuis une app « barre de menus ».
@MainActor
final class WindowPresenter {
    static let shared = WindowPresenter()
    private var windows: [String: NSWindow] = [:]

    func showOnboarding() {
        show(id: "onboarding", title: "Bienvenue dans Precog", size: NSSize(width: 560, height: 680), dark: true) {
            OnboardingView()
        }
    }

    func showSettings() {
        show(id: "settings", title: "Réglages de Precog", size: NSSize(width: 480, height: 600), dark: false) {
            SettingsView()
        }
    }

    /// Fenêtre hologramme flottante : reste au premier plan et sur tous les bureaux,
    /// pour qu'on voie la main ET le bureau qui glisse pendant l'enregistrement d'une démo.
    func showHologram() {
        NSApp.activate()
        if let window = windows["hologram"] {
            window.orderFrontRegardless()
            return
        }

        let size = NSSize(width: 640, height: 400)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.title = "Precog — Hologramme"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = .black
        panel.contentMinSize = NSSize(width: 320, height: 200)
        panel.contentView = NSHostingView(rootView: HologramView().environment(PrecogController.shared))

        // En bas à droite de l'écran principal
        if let visible = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 24, y: visible.minY + 24))
        } else {
            panel.center()
        }

        windows["hologram"] = panel
        panel.orderFrontRegardless()
    }

    func close(_ id: String) {
        windows[id]?.close()
    }

    private func show<Content: View>(id: String,
                                     title: String,
                                     size: NSSize,
                                     dark: Bool,
                                     @ViewBuilder content: () -> Content) {
        NSApp.activate()

        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: content().environment(PrecogController.shared))
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        if dark { window.appearance = NSAppearance(named: .darkAqua) }
        window.setContentSize(size)
        window.center()

        windows[id] = window
        window.makeKeyAndOrderFront(nil)
    }
}
