import SwiftUI

@main
struct iPhoneRestReminderApp: App {
    @StateObject private var reminderManager = ReminderManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(reminderManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                reminderManager.sceneDidBecomeActive()
            case .background:
                reminderManager.sceneDidEnterBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
