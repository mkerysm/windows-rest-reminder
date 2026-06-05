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
            if newPhase == .active {
                reminderManager.refresh()
            }
        }
    }
}
