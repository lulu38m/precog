import SwiftUI
import Combine

/// Écran d'accueil : explique le geste et guide l'utilisateur pour les autorisations.
struct OnboardingView: View {
    @State private var camera = Permissions.camera
    @State private var accessibility = Permissions.isAccessibilityTrusted
    @AppStorage(Prefs.onboardingDone) private var onboardingDone = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var allGranted: Bool { camera == .granted && accessibility }

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    howItWorks
                    VStack(spacing: 12) {
                        cameraCard
                        accessibilityCard
                        shortcutsCard
                    }
                    footer
                }
                .padding(.horizontal, 32)
                .padding(.top, 44)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.never)
        }
        .frame(minWidth: 560, minHeight: 680)
        .onReceive(timer) { _ in refresh() }
        .onAppear(perform: refresh)
    }

    // MARK: - Sections

    private var background: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.07)
            RadialGradient(colors: [Theme.neon.opacity(0.28), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Theme.violet.opacity(0.30), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fingers.spread.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Theme.brandGradient)
                .shadow(color: Theme.neon.opacity(0.5), radius: 18)
                .symbolEffect(.pulse)
            Text("Pilote ton Mac à mains nues")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Montre tes doigts tendus, puis balaie : tu changes de bureau, comme dans Minority Report.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var howItWorks: some View {
        HStack(spacing: 10) {
            step(symbol: "hand.raised.fill", text: "Doigts tendus ¼ s")
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
            step(symbol: "bolt.fill", text: "Armé", color: Theme.armed)
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
            step(symbol: "arrow.left.and.right", text: "Balaie ← →")
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .precogGlass(cornerRadius: 18)
    }

    private func step(symbol: String, text: String, color: Color = Theme.neon) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private var cameraCard: some View {
        StepCard(number: 1,
                 symbol: "camera.fill",
                 title: "Caméra",
                 detail: "Precog analyse ta main en direct. Tout reste sur ton Mac : aucune image n'est enregistrée ni envoyée.",
                 isDone: camera == .granted) {
            switch camera {
            case .notDetermined:
                Button("Autoriser") {
                    Task {
                        _ = await Permissions.requestCamera()
                        refresh()
                        PrecogController.shared.applyEnabledState()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.neon)
            case .denied:
                Button("Ouvrir les Réglages") { Permissions.openCameraSettings() }
            case .granted:
                EmptyView()
            }
        }
    }

    private var accessibilityCard: some View {
        StepCard(number: 2,
                 symbol: "accessibility",
                 title: "Accessibilité",
                 detail: accessibility
                    ? "Precog peut simuler les raccourcis ⌃← et ⌃→ pour changer de bureau."
                    : "Nécessaire pour que tes gestes changent de bureau. Si Precog est déjà dans la liste mais que ça ne marche pas, retire-le (−) puis ajoute-le à nouveau.",
                 isDone: accessibility) {
            if !accessibility {
                Button("Autoriser") {
                    Permissions.promptAccessibility()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.neon)
            }
        }
    }

    private var shortcutsCard: some View {
        StepCard(number: 3,
                 symbol: "keyboard",
                 title: "Raccourcis Mission Control",
                 detail: "Vérifie que « Aller d'un espace à gauche / à droite » est coché dans Réglages › Clavier › Raccourcis clavier › Mission Control. C'est le cas par défaut. Pense aussi à créer au moins 2 bureaux.",
                 isDone: nil) {
            Button("Ouvrir") { Permissions.openKeyboardShortcutsSettings() }
        }
    }

    private var footer: some View {
        HStack {
            Button("Plus tard") { finish() }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Button {
                finish()
            } label: {
                Label("C'est parti", systemImage: "sparkles")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.neon)
            .controlSize(.large)
            .disabled(!allGranted)
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func refresh() {
        camera = Permissions.camera
        accessibility = Permissions.isAccessibilityTrusted
    }

    private func finish() {
        onboardingDone = true
        let controller = PrecogController.shared
        if !controller.isEnabled {
            controller.isEnabled = true
        } else {
            controller.applyEnabledState()
        }
        WindowPresenter.shared.close("onboarding")
    }
}

/// Carte d'étape avec numéro, explication et action.
struct StepCard<Accessory: View>: View {
    let number: Int
    let symbol: String
    let title: String
    let detail: String
    /// nil = étape informative (pas de statut).
    let isDone: Bool?
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill((isDone == true ? Theme.armed : Theme.neon).opacity(0.18))
                Image(systemName: isDone == true ? "checkmark" : symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isDone == true ? Theme.armed : Theme.neon)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(number).").foregroundStyle(.white.opacity(0.5))
                    Text(title).foregroundStyle(.white)
                }
                .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isDone == true {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.armed)
                    .transition(.scale.combined(with: .opacity))
            } else {
                accessory()
            }
        }
        .padding(16)
        .precogGlass(cornerRadius: 18)
        .animation(.spring(duration: 0.35), value: isDone)
    }
}
