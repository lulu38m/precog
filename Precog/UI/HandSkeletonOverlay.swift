import SwiftUI

/// Dessine le squelette de la main en néon par-dessus l'aperçu caméra.
struct HandSkeletonOverlay: View {
    let joints: [HandJoint: CGPoint]
    let imageSize: CGSize
    let armed: Bool
    var lineWidth: CGFloat = 2.5

    private static let chains: [[HandJoint]] = [
        [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
        [.indexMCP, .middleMCP, .ringMCP, .littleMCP]
    ]

    var body: some View {
        Canvas { context, size in
            guard imageSize.width > 0, imageSize.height > 0, !joints.isEmpty else { return }
            let map = Self.mapper(viewSize: size, imageSize: imageSize)
            let color = armed ? Theme.armed : Theme.neon

            var bones = Path()
            for chain in Self.chains {
                var started = false
                for joint in chain {
                    guard let point = joints[joint] else { started = false; continue }
                    let mapped = map(point)
                    if started {
                        bones.addLine(to: mapped)
                    } else {
                        bones.move(to: mapped)
                        started = true
                    }
                }
            }

            let radius = lineWidth * 1.4
            var dots = Path()
            for point in joints.values {
                let center = map(point)
                dots.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }

            // Halo lumineux
            var glow = context
            glow.addFilter(.blur(radius: lineWidth * 2.8))
            glow.stroke(bones, with: .color(color), style: StrokeStyle(lineWidth: lineWidth * 2.8, lineCap: .round, lineJoin: .round))
            glow.fill(dots, with: .color(color))

            // Trait net
            context.stroke(bones, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            context.fill(dots, with: .color(.white))
        }
        .allowsHitTesting(false)
    }

    /// Convertit un point Vision (normalisé, origine en bas à gauche) vers la vue,
    /// en tenant compte du remplissage (aspect fill) et du miroir de l'aperçu.
    static func mapper(viewSize: CGSize, imageSize: CGSize) -> (CGPoint) -> CGPoint {
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let displayed = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (viewSize.width - displayed.width) / 2,
                             y: (viewSize.height - displayed.height) / 2)
        return { point in
            CGPoint(x: origin.x + (1 - point.x) * displayed.width,
                    y: origin.y + (1 - point.y) * displayed.height)
        }
    }
}

/// Coins de visée façon interface de film.
struct CornerBrackets: View {
    var color: Color
    var length: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, l = length
            Path { path in
                path.move(to: CGPoint(x: 0, y: l)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: l, y: 0))
                path.move(to: CGPoint(x: w - l, y: 0)); path.addLine(to: CGPoint(x: w, y: 0)); path.addLine(to: CGPoint(x: w, y: l))
                path.move(to: CGPoint(x: w, y: h - l)); path.addLine(to: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: w - l, y: h))
                path.move(to: CGPoint(x: l, y: h)); path.addLine(to: CGPoint(x: 0, y: h)); path.addLine(to: CGPoint(x: 0, y: h - l))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }
}
