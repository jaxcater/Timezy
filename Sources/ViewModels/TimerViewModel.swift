import Foundation
import Combine

// Chế độ của Pomodoro
enum FocusMode: String, CaseIterable {
    case focus = "Tập trung"
    case shortBreak = "Nghỉ ngắn"
    case longBreak = "Nghỉ dài"

    // Số giây tương ứng mỗi chế độ
    var seconds: Int {
        switch self {
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
}

// ViewModel điều khiển đồng hồ Pomodoro
final class TimerViewModel: ObservableObject {
    @Published var mode: FocusMode = .focus
    @Published var remainingSeconds: Int = FocusMode.focus.seconds
    @Published var isRunning: Bool = false
    @Published var completedPomodorosToday: Int = 0
    @Published var focusedSecondsToday: Int = 0

    private var timer: AnyCancellable?
    private let todayKey: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "timezy.stats." + f.string(from: Date())
    }()

    init() {
        completedPomodorosToday = UserDefaults.standard.integer(forKey: todayKey + ".pomodoros")
        focusedSecondsToday = UserDefaults.standard.integer(forKey: todayKey + ".seconds")
    }

    // Đổi chế độ → reset đồng hồ
    func selectMode(_ newMode: FocusMode) {
        stop()
        mode = newMode
        remainingSeconds = newMode.seconds
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }

    func reset() {
        stop()
        remainingSeconds = mode.seconds
    }

    // Chuỗi hiển thị mm:ss
    var timeString: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    // Tiến trình 0...1 để vẽ vòng tròn
    var progress: Double {
        let total = Double(mode.seconds)
        guard total > 0 else { return 0 }
        return 1 - Double(remainingSeconds) / total
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            finishSession()
            return
        }
        remainingSeconds -= 1
        if mode == .focus {
            focusedSecondsToday += 1
            persist()
        }
        if remainingSeconds == 0 {
            finishSession()
        }
    }

    private func finishSession() {
        stop()
        if mode == .focus {
            completedPomodorosToday += 1
            persist()
        }
        // TODO: phát âm thanh + gửi local notification ở bản sau
    }

    private func persist() {
        UserDefaults.standard.set(completedPomodorosToday, forKey: todayKey + ".pomodoros")
        UserDefaults.standard.set(focusedSecondsToday, forKey: todayKey + ".seconds")
    }
}
