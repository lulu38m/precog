import SwiftUI
import Observation

/// État global de l'app : relie la caméra, le moteur de gestes, les actions et l'interface.
@MainActor
@Observable
final class PrecogController {
    static let shared = PrecogController()

    /// Interrupteur principal (barre de menus, raccourci d'arrêt d'urgence).
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Prefs.enabled)
            applyEnabledState()
        }
    }

    private(set) var status: EngineStatus = .off
    /// Points de la main, en coordonnées Vision (normalisées, origine en bas à gauche, image non miroir).
    private(set) var joints: [HandJoint: CGPoint] = [:]
    private(set) var imageSize: CGSize = .zero
    private(set) var armProgress: Double = 0
    private(set) var lastAction: PrecogAction?
    /// Dernières positions du centre de la main (coordonnées Vision), pour la traînée du mode hologramme.
    private(set) var palmTrail: [CGPoint] = []
    private let trailLength = 14

    let camera = CameraManager()
    private let engine = GestureEngine()
    private let hotkey = HotkeyMonitor()

    private init() {
        Prefs.registerDefaults()
        isEnabled = UserDefaults.standard.bool(forKey: Prefs.enabled)
    }

    func start() {
        camera.onHandFrame = { [weak self] frame in
            self?.handle(frame)
        }
        hotkey.onTrigger = { [weak self] in
            self?.toggleFromShortcut()
        }
        hotkey.start()
        applyEnabledState()
    }

    /// Démarre ou coupe la caméra selon l'interrupteur et l'autorisation caméra.
    func applyEnabledState() {
        if isEnabled && Permissions.camera == .granted {
            camera.start()
            if status == .off || status == .noPermission { status = .searching }
        } else {
            camera.stop()
            engine.reset()
            joints = [:]
            palmTrail = []
            armProgress = 0
            status = isEnabled ? .noPermission : .off
        }
    }

    private func handle(_ frame: HandFrame?) {
        guard isEnabled else { return }

        joints = frame?.joints ?? [:]
        if let size = frame?.imageSize { imageSize = size }

        if let frame, let center = GestureEngine.handCenter(frame.joints) {
            palmTrail.append(center)
            if palmTrail.count > trailLength {
                palmTrail.removeFirst(palmTrail.count - trailLength)
            }
        } else if !palmTrail.isEmpty {
            palmTrail = []
        }

        let output = engine.process(frame, settings: .current)
        armProgress = output.armProgress

        if output.isArmed {
            status = .armed
        } else {
            status = frame == nil ? .searching : .handDetected
        }

        if let action = output.triggered {
            lastAction = action
            ActionPerformer.perform(action)
            if UserDefaults.standard.bool(forKey: Prefs.showHUD) {
                HUDController.shared.show(symbol: action.symbol, title: action.title)
            }
        }
    }

    private func toggleFromShortcut() {
        isEnabled.toggle()
        HUDController.shared.show(
            symbol: isEnabled ? "hand.raised.fill" : "hand.raised.slash.fill",
            title: isEnabled ? "Precog activé" : "Precog en pause"
        )
    }
}

enum EngineStatus: Equatable {
    case off, noPermission, searching, handDetected, armed

    var label: String {
        switch self {
        case .off: "En pause"
        case .noPermission: "Autorisation requise"
        case .searching: "Cherche ta main…"
        case .handDetected: "Main détectée"
        case .armed: "Armé"
        }
    }

    var color: Color {
        switch self {
        case .off: .secondary
        case .noPermission: .orange
        case .searching: .secondary
        case .handDetected: Theme.neon
        case .armed: Theme.armed
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .off: "hand.raised.slash"
        case .noPermission: "exclamationmark.triangle"
        case .searching: "hand.raised"
        case .handDetected: "hand.raised.fill"
        case .armed: "hand.raised.fingers.spread.fill"
        }
    }
}
