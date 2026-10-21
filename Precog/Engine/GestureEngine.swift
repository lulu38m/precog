import CoreGraphics
import QuartzCore
import Vision

typealias HandJoint = VNHumanHandPoseObservation.JointName

struct HandFrame {
    let joints: [HandJoint: CGPoint]
    let imageSize: CGSize
    let timestamp: TimeInterval
}

struct EngineOutput {
    var isArmed = false
    var armProgress: Double = 0
    var triggered: PrecogAction?
}

/// Transforme une suite de positions de la main en gestes.
///
/// Fonctionnement :
/// 1. Doigts tendus et immobiles pendant ~0,2 s → l'engin est « armé ».
///    Il suffit de voir les doigts : le poignet et la paume peuvent être hors champ.
/// 2. Pendant 1,6 s, un mouvement rapide et ample déclenche une action.
/// 3. Petit délai de repos ensuite pour éviter les doubles déclenchements.
///
/// Le mouvement est mesuré par le déplacement moyen des articulations visibles d'une image
/// à l'autre (et non par une position absolue) : si un doigt disparaît un instant pendant
/// un balayage rapide, la mesure ne saute pas.
final class GestureEngine {
    private let armDuration: TimeInterval = 0.22
    private let armedWindow: TimeInterval = 1.6
    private let cooldown: TimeInterval = 0.9
    private let motionWindow: TimeInterval = 0.45
    private let armStillness: CGFloat = 0.10

    private var palmOpenSince: TimeInterval?
    private var armingAnchor: CGPoint = .zero
    private var armedUntil: TimeInterval = 0
    private var cooldownUntil: TimeInterval = 0
    private var samples: [(t: TimeInterval, p: CGPoint)] = []

    /// Position « virtuelle » de la main, obtenue en cumulant les déplacements image par image.
    private var trackedPosition = CGPoint(x: 0.5, y: 0.5)
    private var previousJoints: [HandJoint: CGPoint]?

    func reset() {
        palmOpenSince = nil
        armedUntil = 0
        samples.removeAll()
        previousJoints = nil
    }

    func process(_ frame: HandFrame?, settings: GestureSettings) -> EngineOutput {
        let now = frame?.timestamp ?? CACurrentMediaTime()
        let armed = now < armedUntil

        guard let frame, updateTracking(with: frame.joints) else {
            palmOpenSince = nil
            previousJoints = frame?.joints
            // La main est sortie du champ pendant un balayage rapide : on tente de conclure le geste.
            if armed, let action = detect(threshold: settings.distanceThreshold * 0.6, settings: settings) {
                return fire(action, at: now)
            }
            if !armed { samples.removeAll() }
            return EngineOutput(isArmed: armed)
        }

        let point = trackedPosition

        if now < cooldownUntil {
            palmOpenSince = nil
            return EngineOutput()
        }

        if armed {
            samples.append((now, point))
            samples.removeAll { now - $0.t > motionWindow }
            if let action = detect(threshold: settings.distanceThreshold, settings: settings) {
                return fire(action, at: now)
            }
            return EngineOutput(isArmed: true, armProgress: 1)
        }

        // Phase d'armement : doigts tendus et (presque) immobiles.
        guard Self.isOpenHand(frame.joints) else {
            palmOpenSince = nil
            return EngineOutput()
        }

        if let since = palmOpenSince, Self.distance(point, armingAnchor) <= armStillness {
            let progress = (now - since) / armDuration
            if progress >= 1 {
                palmOpenSince = nil
                armedUntil = now + armedWindow
                samples = [(now, point)]
                return EngineOutput(isArmed: true, armProgress: 1)
            }
            return EngineOutput(armProgress: progress)
        }

        palmOpenSince = now
        armingAnchor = point
        return EngineOutput()
    }

    // MARK: - Suivi du mouvement

    /// Met à jour la position virtuelle à partir des articulations visibles sur deux images consécutives.
    /// Renvoie false si la main n'est pas exploitable sur cette image.
    private func updateTracking(with joints: [HandJoint: CGPoint]) -> Bool {
        defer { previousJoints = joints }
        guard joints.count >= 5 else { return false }

        guard let previous = previousJoints else { return true }
        let common = joints.keys.filter { previous[$0] != nil }
        guard common.count >= 3 else { return true }

        var dx: CGFloat = 0, dy: CGFloat = 0
        for joint in common {
            dx += joints[joint]!.x - previous[joint]!.x
            dy += joints[joint]!.y - previous[joint]!.y
        }
        let count = CGFloat(common.count)
        // Point de vue de l'utilisateur : l'image caméra est inversée gauche/droite.
        trackedPosition.x -= dx / count
        trackedPosition.y += dy / count
        return true
    }

    // MARK: - Détection du mouvement

    private func detect(threshold: CGFloat, settings: GestureSettings) -> PrecogAction? {
        guard samples.count >= 2, let first = samples.first, let last = samples.last else { return nil }
        let dx = last.p.x - first.p.x
        let dy = last.p.y - first.p.y

        let motion: HandMotion?
        if abs(dx) >= threshold, abs(dx) > abs(dy) * 1.4 {
            motion = dx > 0 ? .right : .left
        } else if abs(dy) >= threshold * 0.8, abs(dy) > abs(dx) * 1.4 {
            motion = dy > 0 ? .up : .down // Vision : l'axe Y monte
        } else {
            motion = nil
        }
        return motion.flatMap { settings.action(for: $0) }
    }

    private func fire(_ action: PrecogAction, at now: TimeInterval) -> EngineOutput {
        armedUntil = 0
        cooldownUntil = now + cooldown
        samples.removeAll()
        palmOpenSince = nil
        return EngineOutput(triggered: action)
    }

    // MARK: - Géométrie de la main

    /// Centre de la main pour l'affichage (traînée lumineuse) : moyenne des articulations visibles.
    static func handCenter(_ joints: [HandJoint: CGPoint]) -> CGPoint? {
        guard !joints.isEmpty else { return nil }
        let sum = joints.values.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(joints.count), y: sum.y / CGFloat(joints.count))
    }

    private static let fingers: [[HandJoint]] = [
        [.indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.littleMCP, .littlePIP, .littleDIP, .littleTip]
    ]

    /// Main ouverte = au moins 3 doigts tendus et aucun doigt replié.
    /// Chaque doigt est jugé sur sa propre forme (est-il droit ?), sans besoin du poignet.
    static func isOpenHand(_ joints: [HandJoint: CGPoint]) -> Bool {
        var extended = 0
        var folded = 0
        for chain in fingers {
            switch fingerState(chain.compactMap { joints[$0] }) {
            case .extended: extended += 1
            case .folded: folded += 1
            case .unknown: break
            }
        }
        return extended >= 3 && folded == 0
    }

    private enum FingerState { case extended, folded, unknown }

    /// Un doigt tendu forme une ligne presque droite : la distance base → bout
    /// est proche de la longueur du chemin qui passe par chaque articulation.
    private static func fingerState(_ points: [CGPoint]) -> FingerState {
        guard points.count >= 3, let first = points.first, let last = points.last else { return .unknown }
        var path: CGFloat = 0
        for index in 1..<points.count {
            path += distance(points[index - 1], points[index])
        }
        guard path > 0.02 else { return .unknown } // doigt trop petit à l'image pour juger
        let straightness = distance(first, last) / path
        if straightness > 0.82 { return .extended }
        if straightness < 0.55 { return .folded }
        return .unknown
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
