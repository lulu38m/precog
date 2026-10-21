import SwiftUI

@main
struct PrecogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var controller = PrecogController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView()
                .environment(controller)
        } label: {
            Image(systemName: controller.status.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = PrecogController.shared
        controller.start()

        let onboardingDone = UserDefaults.standard.bool(forKey: Prefs.onboardingDone)
        if !onboardingDone || !Permissions.allGranted {
            WindowPresenter.shared.showOnboarding()
        }
    }
}
