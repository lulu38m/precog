import SwiftUI
import AppKit

enum Theme {
    static let neon = Color(red: 0.00, green: 0.90, blue: 1.00)
    static let armed = Color(red: 0.24, green: 1.00, blue: 0.63)
    static let violet = Color(red: 0.55, green: 0.36, blue: 1.00)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [neon, violet], startPoint: .leading, endPoint: .trailing)
    }
}

extension View {
    /// Effet « verre » natif (Liquid Glass) sur macOS 26, matériau flou sur les versions précédentes.
    @ViewBuilder
    func precogGlass(cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        #else
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        #endif
    }
}

/// Flou « derrière la fenêtre », comme la bulle de volume de macOS.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.roundedMask(radius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
