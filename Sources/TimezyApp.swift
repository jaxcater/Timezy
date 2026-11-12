import SwiftUI

// Entry point của app Timezy
@main
struct TimezyApp: App {
    @StateObject private var timerVM = TimerViewModel()
    @StateObject private var taskVM = TaskListViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerVM)
                .environmentObject(taskVM)
        }
    }
}
