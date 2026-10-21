import AppKit
import AVFoundation
import ApplicationServices

enum PermissionState {
    case granted, denied, notDetermined
}

enum Permissions {
    static var camera: PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    static func requestCamera() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Affiche la fenêtre système qui propose d'ouvrir les réglages d'Accessibilité.
    static func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static var allGranted: Bool {
        camera == .granted && isAccessibilityTrusted
    }

    static func openCameraSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
    }

    static func openKeyboardShortcutsSettings() {
        open("x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts")
    }

    private static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
