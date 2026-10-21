import CoreGraphics

/// Simule les raccourcis système de macOS (⌃← ⌃→ ⌃↑ ⌃↓).
/// Nécessite l'autorisation « Accessibilité ».
enum ActionPerformer {
    private static let controlKey: CGKeyCode = 59

    static func perform(_ action: PrecogAction) {
        guard Permissions.isAccessibilityTrusted else { return }
        let source = CGEventSource(stateID: .hidSystemState)

        // Les flèches portent les drapeaux « fn » et « pavé numérique » quand on les tape au clavier :
        // on les reproduit, sinon Mission Control ignore parfois l'événement.
        let arrowFlags: CGEventFlags = [.maskControl, .maskSecondaryFn, .maskNumericPad]

        guard let ctrlDown = CGEvent(keyboardEventSource: source, virtualKey: controlKey, keyDown: true),
              let arrowDown = CGEvent(keyboardEventSource: source, virtualKey: action.keyCode, keyDown: true),
              let arrowUp = CGEvent(keyboardEventSource: source, virtualKey: action.keyCode, keyDown: false),
              let ctrlUp = CGEvent(keyboardEventSource: source, virtualKey: controlKey, keyDown: false)
        else { return }

        ctrlDown.flags = .maskControl
        arrowDown.flags = arrowFlags
        arrowUp.flags = arrowFlags
        ctrlUp.flags = []

        for event in [ctrlDown, arrowDown, arrowUp, ctrlUp] {
            event.post(tap: .cghidEventTap)
        }
    }
}
