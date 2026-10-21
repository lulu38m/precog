import SwiftUI
import AVFoundation

/// Aperçu caméra en miroir (comme Photo Booth).
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
        PreviewNSView(session: session)
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        nsView.applyMirroring()
    }
}

final class PreviewNSView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
        applyMirroring()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) n'est pas utilisé")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
        applyMirroring()
    }

    /// La connexion n'existe qu'une fois la caméra configurée : on réessaie à chaque mise à jour.
    func applyMirroring() {
        guard let connection = previewLayer.connection,
              connection.isVideoMirroringSupported,
              !connection.isVideoMirrored else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }
}
