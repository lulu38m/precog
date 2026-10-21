import SwiftUI

/// Le panneau qui s'ouvre depuis l'icône de la barre de menus.
struct MenuPanelView: View {
    @Environment(PrecogController.self) private var controller
    @AppStorage(Prefs.showSkeleton) private var showSkeleton = true
    @AppStorage(Prefs.hologramMode) private var hologramMode = false

    private let panelWidth: CGFloat = 460
    private let panelPadding: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            // Toute la largeur du panneau, au format de l'image caméra (4:3 ou 16:9) : rien n'est rogné.
            preview
                .frame(width: previewWidth, height: previewWidth / previewAspect)
            hintRow
            if !Permissions.isAccessibilityTrusted {
                accessibilityWarning
            }
            Divider().opacity(0.5)
            footer
        }
        .padding(panelPadding)
        .frame(width: panelWidth)
    }

    // MARK: - En-tête

    @ViewBuilder
    private var header: some View {
        @Bindable var controller = controller
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("PRECOG")
                    .font(.system(size: 17, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(Theme.brandGradient)
                StatusPill(status: controller.status)
            }
            Spacer()
            Toggle("Activer Precog", isOn: $controller.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.neon)
        }
    }

    // MARK: - Aperçu caméra

    private var previewWidth: CGFloat { panelWidth - panelPadding * 2 }

    private var previewAspect: CGFloat {
        let size = controller.imageSize
        guard size.width > 0, size.height > 0 else { return 16.0 / 9.0 }
        return size.width / size.height
    }

    private var preview: some View {
        ZStack {
            Color.black
            switch controller.status {
            case .off:
                placeholder(symbol: "hand.raised.slash",
                            title: "Precog est en pause",
                            subtitle: "Active l'interrupteur pour allumer la caméra.")
            case .noPermission:
                VStack(spacing: 10) {
                    placeholder(symbol: "camera.fill",
                                title: "Caméra non autorisée",
                                subtitle: "Precog a besoin de voir ta main.")
                    Button("Autoriser la caméra") { WindowPresenter.shared.showOnboarding() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.neon)
                }
            default:
                if hologramMode {
                    HologramView(compact: true)
                        .transition(.opacity)
                } else {
                    CameraPreview(session: controller.camera.session)
                    if showSkeleton {
                        HandSkeletonOverlay(joints: controller.joints,
                                            imageSize: controller.imageSize,
                                            armed: controller.status == .armed)
                    }
                    CornerBrackets(color: controller.status.color.opacity(0.85))
                        .padding(10)
                }
                hologramToggle
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(controller.status.color.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: controller.status == .armed ? Theme.armed.opacity(0.35) : .clear, radius: 12)
        .animation(.easeInOut(duration: 0.25), value: controller.status)
    }

    /// Bascule caméra / hologramme, en haut à droite de l'aperçu.
    private var hologramToggle: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { hologramMode.toggle() }
                } label: {
                    Label(hologramMode ? "Caméra" : "Holo",
                          systemImage: hologramMode ? "camera.fill" : "cube.transparent")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.neon.opacity(0.5), lineWidth: 1))
                        .foregroundStyle(Theme.neon)
                }
                .buttonStyle(.plain)
                .help(hologramMode ? "Afficher l'image de la caméra" : "Mode hologramme : seule ta main en néon est affichée")
            }
            Spacer()
        }
        .padding(10)
    }

    private func placeholder(symbol: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.brandGradient)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Aide contextuelle

    private var hintRow: some View {
        HStack(spacing: 12) {
            ArmRing(progress: controller.armProgress, armed: controller.status == .armed)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(hint.title)
                    .font(.callout.weight(.semibold))
                Text(hint.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let action = controller.lastAction {
                Label(action.title, systemImage: action.symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                    .help("Dernier geste : \(action.title)")
            }
        }
    }

    private var hint: (title: String, subtitle: String) {
        switch controller.status {
        case .off:
            (title: "En pause", subtitle: "Raccourci \(KillSwitch.current.label) pour réactiver.")
        case .noPermission:
            (title: "Autorisation requise", subtitle: "Ouvre le guide pour autoriser la caméra.")
        case .searching:
            (title: "Montre tes doigts", subtitle: "Doigts tendus, face à la caméra.")
        case .handDetected:
            (title: "Garde les doigts tendus…", subtitle: "Ça s'arme en un instant.")
        case .armed:
            (title: "Armé ! Balaie maintenant", subtitle: "← → bureaux · ↑ Mission Control")
        }
    }

    private var accessibilityWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Accessibilité non autorisée : les gestes sont détectés mais ne changent pas de bureau.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Régler") { WindowPresenter.shared.showOnboarding() }
                .controlSize(.small)
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Pied de page

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                WindowPresenter.shared.showSettings()
            } label: {
                Label("Réglages", systemImage: "gearshape")
            }
            Button {
                WindowPresenter.shared.showHologram()
            } label: {
                Label("Hologramme", systemImage: "cube.transparent")
            }
            .help("Fenêtre flottante, visible sur tous les bureaux : parfaite pour filmer une démo")
            Button {
                WindowPresenter.shared.showOnboarding()
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .help("Guide de bienvenue")
            Spacer()
            Button("Quitter") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }
}

// MARK: - Composants

struct StatusPill: View {
    let status: EngineStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
                .shadow(color: status.color, radius: status == .armed ? 4 : 0)
            Text(status.label)
                .font(.caption.weight(.medium))
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.15), in: Capsule())
        .foregroundStyle(status == .off || status == .searching ? Color.secondary : status.color)
        .animation(.spring(duration: 0.3), value: status)
    }
}

/// Anneau qui se remplit pendant l'armement.
struct ArmRing: View {
    let progress: Double
    let armed: Bool

    var body: some View {
        let color = armed ? Theme.armed : Theme.neon
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: armed ? 1 : min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.7), radius: armed ? 4 : 0)
            Image(systemName: armed ? "bolt.fill" : "hand.raised.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(progress > 0 || armed ? color : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .animation(.spring(duration: 0.25), value: progress)
        .animation(.spring(duration: 0.3), value: armed)
    }
}
