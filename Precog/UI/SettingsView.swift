import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(Prefs.gestureHorizontal) private var horizontal = true
    @AppStorage(Prefs.direction) private var direction: SwipeDirection = .trackpad
    @AppStorage(Prefs.gestureUp) private var up = true
    @AppStorage(Prefs.gestureDown) private var down = false
    @AppStorage(Prefs.sensitivity) private var sensitivity = 0.5
    @AppStorage(Prefs.showHUD) private var showHUD = true
    @AppStorage(Prefs.showSkeleton) private var showSkeleton = true
    @AppStorage(Prefs.hologramMode) private var hologramMode = false
    @AppStorage(Prefs.cameraID) private var cameraID = ""

    @State private var cameras = CameraManager.availableCameras
    @AppStorage(Prefs.killSwitch) private var killSwitch: KillSwitch = .controlOptionCommandG

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $horizontal) {
                    Label("Balayer ← → : changer de bureau", systemImage: "arrow.left.and.right")
                }
                if horizontal {
                    Picker("Sens", selection: $direction) {
                        ForEach(SwipeDirection.allCases) { Text($0.label).tag($0) }
                    }
                    Text(direction.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle(isOn: $up) {
                    Label("Balayer ↑ : Mission Control", systemImage: "rectangle.3.group")
                }
                Toggle(isOn: $down) {
                    Label("Balayer ↓ : fenêtres de l'app", systemImage: "macwindow.on.rectangle")
                }
            } header: {
                Text("Gestes")
            }

            Section {
                Picker("Caméra", selection: $cameraID) {
                    Text("Caméra intégrée (par défaut)").tag("")
                    ForEach(cameras) { camera in
                        Text(camera.name).tag(camera.id)
                    }
                }
                .onChange(of: cameraID) { _, _ in
                    PrecogController.shared.camera.reloadCamera()
                }
                Text("« Vue du bureau » (Desk View) filme le bureau d'en haut : tu peux faire tes gestes juste au-dessus du clavier. Astuce : avec la caméra intégrée, incliner un peu l'écran vers toi fait viser la caméra plus bas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Actualiser la liste des caméras") {
                    cameras = CameraManager.availableCameras
                }
            } header: {
                Text("Caméra")
            }

            Section {
                Slider(value: $sensitivity, in: 0...1) {
                    Text("Sensibilité")
                } minimumValueLabel: {
                    Text("Ample").font(.caption)
                } maximumValueLabel: {
                    Text("Léger").font(.caption)
                }
                Text("« Ample » demande un grand geste (moins de déclenchements involontaires). « Léger » réagit à un petit mouvement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Détection")
            }

            Section {
                Toggle("Bulle de confirmation à l'écran", isOn: $showHUD)
                Toggle("Squelette de la main dans l'aperçu", isOn: $showSkeleton)
                Toggle(isOn: $hologramMode) {
                    Label("Mode hologramme dans le panneau", systemImage: "cube.transparent")
                }
                Text("Remplace l'image de la caméra par ta main en néon sur fond noir. Ton visage n'apparaît jamais : idéal pour filmer une démo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Tester la bulle") {
                        HUDController.shared.show(symbol: PrecogAction.nextDesktop.symbol,
                                                  title: PrecogAction.nextDesktop.title)
                    }
                    Button("Ouvrir la fenêtre hologramme") {
                        WindowPresenter.shared.showHologram()
                    }
                }
            } header: {
                Text("Affichage")
            }

            Section {
                Picker("Raccourci", selection: $killSwitch) {
                    ForEach(KillSwitch.allCases) { Text($0.label).tag($0) }
                }
                Text("Met Precog en pause ou le relance instantanément, depuis n'importe quelle app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Arrêt d'urgence")
            }

            Section {
                Toggle("Lancer Precog à l'ouverture de session", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLaunchAtLogin(enabled)
                    }
                Button("Revoir le guide de bienvenue") {
                    WindowPresenter.shared.showOnboarding()
                }
            } header: {
                Text("Général")
            } footer: {
                Text("Precog \(Bundle.main.appVersion) · traitement 100 % local")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 600)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
