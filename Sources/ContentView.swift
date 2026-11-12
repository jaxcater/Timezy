import SwiftUI

// Màn hình chính: 3 tab Timer / Task / Thống kê
struct ContentView: View {
    var body: some View {
        TabView {
            TimerView()
                .tabItem {
                    Label("Tập trung", systemImage: "timer")
                }

            TaskListView()
                .tabItem {
                    Label("Việc cần làm", systemImage: "checklist")
                }

            StatsView()
                .tabItem {
                    Label("Thống kê", systemImage: "chart.bar")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerViewModel())
        .environmentObject(TaskListViewModel())
}
