import SwiftUI

/// Mode hologramme : la main apparaît en néon sur fond noir, sans jamais afficher l'image de la caméra.
/// Idéal pour enregistrer une démo sans se montrer.
struct HologramView: View {
    @Environment(PrecogController.self) private var controller
    var compact = false

    private var armed: Bool { controller.status == .armed }
    private var accent: Color { armed ? Theme.armed : Theme.neon }

    var body: some View {
        ZStack {
            Color.black

            // Halo central qui respire quand la main est armée
            RadialGradient(colors: [accent.opacity(armed ? 0.22 : 0.10), .clear],
                           center: .center, startRadius: 0, endRadius: compact ? 180 : 420)
                .animation(.easeInOut(duration: 0.4), value: armed)

            HologramGrid(color: Theme.neon)

            HandTrail(points: controller.palmTrail, imageSize: controller.imageSize, color: accent)

            HandSkeletonOverlay(joints: controller.joints,
                                imageSize: controller.imageSize,
                                armed: armed,
                                lineWidth: compact ? 2.5 : 3.5)

            Scanlines()

            CornerBrackets(color: accent.opacity(0.9), length: compact ? 16 : 26)
                .padding(compact ? 10 : 18)

            if !compact { overlayText }

            if controller.joints.isEmpty && controller.status != .off {
                Text("EN ATTENTE D'UNE MAIN")
                    .font(.system(size: compact ? 10 : 13, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.neon.opacity(0.55))
                    .phaseAnimator([0.35, 1.0]) { view, opacity in
                        view.opacity(opacity)
                    } animation: { _ in .easeInOut(duration: 1.1) }
            }
        }
        .compositingGroup()
    }

    private var overlayText: some View {
        VStack {
            HStack {
                Text("PRECOG // HOLO")
                Spacer()
                Text(controller.status == .armed ? "● ARMED" : (controller.joints.isEmpty ? "○ SCANNING" : "● TRACKING"))
                    .foregroundStyle(accent)
            }
            Spacer()
            HStack {
                Text(controller.lastAction.map { "LAST: \($0.title.uppercased())" } ?? "LAST: —")
                Spacer()
                Text("21 PTS · VISION · ON-DEVICE")
            }
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .tracking(1.5)
        .foregroundStyle(Theme.neon.opacity(0.7))
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .allowsHitTesting(false)
    }
}

/// Quadrillage en perspective, discret.
struct HologramGrid: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
            var lines = Path()
            var x: CGFloat = 0
            while x <= size.width {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(lines, with: .color(color.opacity(0.07)), lineWidth: 0.5)
        }
        .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 40, endRadius: 520))
        .allowsHitTesting(false)
    }
}

/// Traînée lumineuse qui suit la main : rend les balayages très lisibles en vidéo.
struct HandTrail: View {
    let points: [CGPoint]
    let imageSize: CGSize
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard points.count >= 2, imageSize.width > 0 else { return }
            let map = HandSkeletonOverlay.mapper(viewSize: size, imageSize: imageSize)
            let mapped = points.map(map)
            var glow = context
            glow.addFilter(.blur(radius: 8))
            for index in 1..<mapped.count {
                let progress = CGFloat(index) / CGFloat(mapped.count - 1)
                var segment = Path()
                segment.move(to: mapped[index - 1])
                segment.addLine(to: mapped[index])
                let style = StrokeStyle(lineWidth: 2 + 10 * progress, lineCap: .round)
                glow.stroke(segment, with: .color(color.opacity(0.5 * progress)), style: style)
                context.stroke(segment, with: .color(color.opacity(0.8 * progress)),
                               style: StrokeStyle(lineWidth: 1 + 3 * progress, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Lignes de balayage façon écran holographique.
struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var lines = Path()
            var y: CGFloat = 0
            while y < size.height {
                lines.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                y += 3
            }
            context.fill(lines, with: .color(.black.opacity(0.25)))
        }
        .allowsHitTesting(false)
    }
}
