import AppKit

/// Clés UserDefaults partagées entre le moteur et les vues (@AppStorage).
enum Prefs {
    static let enabled = "enabled"
    static let sensitivity = "sensitivity"
    static let direction = "direction"
    static let gestureHorizontal = "gestureHorizontal"
    static let gestureUp = "gestureUp"
    static let gestureDown = "gestureDown"
    static let showHUD = "showHUD"
    static let showSkeleton = "showSkeleton"
    static let hologramMode = "hologramMode"
    static let cameraID = "cameraID"
    static let killSwitch = "killSwitch"
    static let onboardingDone = "onboardingDone"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            enabled: true,
            sensitivity: 0.5,
            direction: SwipeDirection.trackpad.rawValue,
            gestureHorizontal: true,
            gestureUp: true,
            gestureDown: false,
            showHUD: true,
            showSkeleton: true,
            hologramMode: false,
            cameraID: "",
            killSwitch: KillSwitch.controlOptionCommandG.rawValue,
            onboardingDone: false
        ])
    }
}

/// Raccourci clavier global pour mettre Precog en pause / le relancer.
enum KillSwitch: String, CaseIterable, Identifiable {
    case controlOptionCommandG
    case controlOptionSpace
    case optionCommandP
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .controlOptionCommandG: "⌃⌥⌘G"
        case .controlOptionSpace: "⌃⌥Espace"
        case .optionCommandP: "⌥⌘P"
        case .none: "Aucun"
        }
    }

    var spec: (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)? {
        switch self {
        case .controlOptionCommandG: (5, [.control, .option, .command])
        case .controlOptionSpace: (49, [.control, .option])
        case .optionCommandP: (35, [.option, .command])
        case .none: nil
        }
    }

    static var current: KillSwitch {
        KillSwitch(rawValue: UserDefaults.standard.string(forKey: Prefs.killSwitch) ?? "") ?? .controlOptionCommandG
    }
}

/// Écoute le raccourci d'arrêt d'urgence partout dans macOS.
final class HotkeyMonitor {
    var onTrigger: (@MainActor () -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.check(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            (self?.check(event) ?? false) ? nil : event
        }
    }

    @discardableResult
    private func check(_ event: NSEvent) -> Bool {
        guard let spec = KillSwitch.current.spec else { return false }
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function, .numericPad])
        guard event.keyCode == spec.keyCode, modifiers == spec.modifiers else { return false }

        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.onTrigger?()
            }
        }
        return true
    }
}
