import AppKit
import SwiftUI
import Observation

@Observable
final class HUDModel {
    var symbol = "hand.raised.fill"
    var title = ""
    var pulse = 0
}

/// Bulle flottante façon « volume macOS » qui confirme un geste.
@MainActor
final class HUDController {
    static let shared = HUDController()

    private let model = HUDModel()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?
    private let panelSize = NSSize(width: 230, height: 210)

    func show(symbol: String, title: String) {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        model.symbol = symbol
        model.title = title
        model.pulse += 1

        position(panel)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }, completionHandler: nil)

        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled, let panel = self?.panel else { return }
            // Forme explicite avec completionHandler : dans un contexte async, le SDK de macOS 26
            // choisirait sinon la variante `async` de runAnimationGroup.
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                panel.animator().alphaValue = 0
            }, completionHandler: nil)
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: panelSize),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.alphaValue = 0

        let hosting = NSHostingView(rootView: HUDView(model: model))
        hosting.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = hosting
        return panel
    }

    /// Centrée en bas de l'écran où se trouve la souris, comme la bulle de volume.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        let origin = NSPoint(x: frame.midX - panelSize.width / 2,
                             y: frame.minY + frame.height * 0.16)
        panel.setFrameOrigin(origin)
    }
}

struct HUDView: View {
    let model: HUDModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: model.symbol)
                .font(.system(size: 56, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.neon)
                .shadow(color: Theme.neon.opacity(0.6), radius: 10)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: model.pulse)
            Text(model.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(width: 200, height: 180)
        .background(VisualEffectBackground(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.neon.opacity(0.35), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
