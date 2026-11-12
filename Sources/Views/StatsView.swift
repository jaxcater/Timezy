import SwiftUI

// Màn hình thống kê hôm nay (đọc từ TimerViewModel)
struct StatsView: View {
    @EnvironmentObject var timerVM: TimerViewModel
    @EnvironmentObject var taskVM: TaskListViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                StatCard(
                    title: "Pomodoro hoàn thành",
                    value: "\(timerVM.completedPomodorosToday)",
                    icon: "checkmark.seal.fill"
                )
                StatCard(
                    title: "Phút tập trung",
                    value: "\(timerVM.focusedSecondsToday / 60)",
                    icon: "clock.fill"
                )
                StatCard(
                    title: "Task đã xong",
                    value: "\(taskVM.doneTasks.count)/\(taskVM.tasks.count)",
                    icon: "list.bullet.clipboard.fill"
                )
                Spacer()
                Text("Số liệu reset theo ngày, lưu trên máy (UserDefaults). Bản sau sẽ dùng SwiftData để xem lịch sử tuần/tháng.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Thống kê")
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.accent)
                .frame(width: 44)
            VStack(alignment: .leading) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Text(value).font(.title.bold())
            }
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    StatsView()
        .environmentObject(TimerViewModel())
        .environmentObject(TaskListViewModel())
}
