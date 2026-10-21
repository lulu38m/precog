import AVFoundation
import Vision
import QuartzCore

/// Une caméra disponible, pour le choix dans les réglages.
struct CameraOption: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Gère la webcam et lance la détection de la main (Vision) sur chaque image.
/// Tout reste en local : aucune image n'est enregistrée ni envoyée.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()

    /// Appelé sur le thread principal à chaque image (nil = aucune main visible).
    var onHandFrame: (@MainActor (HandFrame?) -> Void)?

    private let sessionQueue = DispatchQueue(label: "precog.camera.session")
    private let videoQueue = DispatchQueue(label: "precog.camera.video", qos: .userInteractive)
    private var isConfigured = false
    private var currentInput: AVCaptureDeviceInput?

    private let handRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()

    // MARK: - Caméras disponibles

    private static var discovery: AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera],
            mediaType: .video,
            position: .unspecified
        )
    }

    static var availableCameras: [CameraOption] {
        discovery.devices.map { CameraOption(id: $0.uniqueID, name: $0.localizedName) }
    }

    /// Caméra choisie dans les réglages, sinon la caméra intégrée.
    private static func preferredDevice() -> AVCaptureDevice? {
        let savedID = UserDefaults.standard.string(forKey: Prefs.cameraID) ?? ""
        if !savedID.isEmpty, let device = AVCaptureDevice(uniqueID: savedID) {
            return device
        }
        return discovery.devices.first { $0.deviceType == .builtInWideAngleCamera }
            ?? AVCaptureDevice.default(for: .video)
    }

    // MARK: - Cycle de vie

    func start() {
        sessionQueue.async { [self] in
            if !isConfigured { configure() }
            if isConfigured && !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Change de caméra à chaud (après un changement dans les réglages).
    func reloadCamera() {
        sessionQueue.async { [self] in
            guard isConfigured else { return }
            session.beginConfiguration()
            if let currentInput { session.removeInput(currentInput) }
            currentInput = nil
            addPreferredInput()
            session.commitConfiguration()
        }
    }

    private func configure() {
        disableCenterStage()

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard addPreferredInput() else { return }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        isConfigured = true
    }

    @discardableResult
    private func addPreferredInput() -> Bool {
        guard let device = Self.preferredDevice(),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return false }
        session.addInput(input)
        currentInput = input
        useWidestFormat(of: device)
        return true
    }

    /// Le Cadre centré zoome sur le visage et rogne la zone où se trouvent les mains : on le coupe pour Precog.
    private func disableCenterStage() {
        AVCaptureDevice.centerStageControlMode = .app
        AVCaptureDevice.isCenterStageEnabled = false
    }

    /// Choisit un format 4:3 (le champ complet du capteur) plutôt que 16:9, qui coupe le haut et le bas.
    /// On reste à une résolution raisonnable pour que la détection de la main reste fluide.
    private func useWidestFormat(of device: AVCaptureDevice) {
        let candidates = device.formats.filter { format in
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let ratio = Double(size.width) / Double(max(size.height, 1))
            let fastEnough = format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 24 }
            return fastEnough && size.width <= 1920 && ratio < 1.5 // 4:3 ou plus « haut »
        }
        let best = candidates.max { a, b in
            CMVideoFormatDescriptionGetDimensions(a.formatDescription).height
                < CMVideoFormatDescriptionGetDimensions(b.formatDescription).height
        }

        if let best, (try? device.lockForConfiguration()) != nil {
            // Sur macOS, il suffit de choisir le format de la caméra : la session le conserve.
            device.activeFormat = best
            device.unlockForConfiguration()
        } else if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else {
            session.sessionPreset = .high
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                               height: CVPixelBufferGetHeight(pixelBuffer))
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        var frame: HandFrame?
        do {
            try handler.perform([handRequest])
            if let observation = handRequest.results?.first {
                let points = try observation.recognizedPoints(.all)
                var joints: [HandJoint: CGPoint] = [:]
                for (name, point) in points where point.confidence > 0.3 {
                    joints[name] = point.location
                }
                if joints.count >= 5 { // quelques doigts suffisent
                    frame = HandFrame(joints: joints, imageSize: imageSize, timestamp: CACurrentMediaTime())
                }
            }
        } catch {
            frame = nil
        }

        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.onHandFrame?(frame)
            }
        }
    }
}
