import SwiftUI

// Màn hình đồng hồ Pomodoro
struct TimerView: View {
    @EnvironmentObject var vm: TimerViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Chọn chế độ
                Picker("Chế độ", selection: $vm.mode) {
                    ForEach(FocusMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.mode) { _, newMode in
                    vm.selectMode(newMode)
                }
                .padding(.horizontal)

                // Vòng tròn tiến trình
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: vm.progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: vm.progress)
                    Text(vm.timeString)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 260, height: 260)
                .padding(.top, 8)

                // Nút điều khiển
                HStack(spacing: 16) {
                    Button(vm.isRunning ? "Tạm dừng" : "Bắt đầu") {
                        vm.isRunning ? vm.stop() : vm.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Đặt lại") {
                        vm.reset()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Text("Hôm nay: \(vm.completedPomodorosToday) pomodoro • \(vm.focusedSecondsToday / 60) phút tập trung")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Timezy")
        }
    }
}

#Preview {
    TimerView().environmentObject(TimerViewModel())
}
