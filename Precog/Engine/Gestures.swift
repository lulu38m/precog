import CoreGraphics
import Foundation

/// Mouvement de la main, vu par l'utilisateur.
enum HandMotion {
    case left, right, up, down
}

/// Ce que Precog fait sur le Mac.
enum PrecogAction: String, CaseIterable {
    case previousDesktop, nextDesktop, missionControl, appExpose

    var title: String {
        switch self {
        case .previousDesktop: "Bureau précédent"
        case .nextDesktop: "Bureau suivant"
        case .missionControl: "Mission Control"
        case .appExpose: "Fenêtres de l'app"
        }
    }

    var symbol: String {
        switch self {
        case .previousDesktop: "arrow.left.circle.fill"
        case .nextDesktop: "arrow.right.circle.fill"
        case .missionControl: "rectangle.3.group.fill"
        case .appExpose: "macwindow.on.rectangle"
        }
    }

    /// Touche fléchée associée au raccourci macOS ⌃ + flèche.
    var keyCode: CGKeyCode {
        switch self {
        case .previousDesktop: 123 // ←
        case .nextDesktop: 124     // →
        case .appExpose: 125       // ↓
        case .missionControl: 126  // ↑
        }
    }
}

/// Sens du balayage horizontal.
enum SwipeDirection: String, CaseIterable, Identifiable {
    /// Comme le trackpad : la main « pousse » le bureau (main vers la gauche → bureau de droite).
    case trackpad
    /// Dans le sens du geste : main vers la droite → bureau de droite.
    case pointing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trackpad: "Comme le trackpad"
        case .pointing: "Dans le sens du geste"
        }
    }

    var detail: String {
        switch self {
        case .trackpad: "Ta main pousse le bureau : balayer vers la gauche affiche le bureau de droite."
        case .pointing: "Balayer vers la droite affiche le bureau de droite."
        }
    }
}

/// Réglages lus à chaque image (lecture UserDefaults, très rapide).
struct GestureSettings {
    var sensitivity: Double
    var direction: SwipeDirection
    var horizontal: Bool
    var up: Bool
    var down: Bool

    static var current: GestureSettings {
        let defaults = UserDefaults.standard
        return GestureSettings(
            sensitivity: defaults.double(forKey: Prefs.sensitivity),
            direction: SwipeDirection(rawValue: defaults.string(forKey: Prefs.direction) ?? "") ?? .trackpad,
            horizontal: defaults.bool(forKey: Prefs.gestureHorizontal),
            up: defaults.bool(forKey: Prefs.gestureUp),
            down: defaults.bool(forKey: Prefs.gestureDown)
        )
    }

    /// Distance à parcourir (en fraction de la largeur de l'image) pour valider un balayage.
    var distanceThreshold: CGFloat {
        CGFloat(0.32 - 0.20 * min(max(sensitivity, 0), 1))
    }

    func action(for motion: HandMotion) -> PrecogAction? {
        switch motion {
        case .left, .right:
            guard horizontal else { return nil }
            let towardsRightDesktop = (motion == .right) == (direction == .pointing)
            return towardsRightDesktop ? .nextDesktop : .previousDesktop
        case .up:
            return up ? .missionControl : nil
        case .down:
            return down ? .appExpose : nil
        }
    }
}
