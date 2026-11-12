import Foundation

// ViewModel quản lý danh sách task, lưu local bằng UserDefaults
final class TaskListViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet { save() }
    }
    @Published var newTitle: String = ""

    private let storageKey = "timezy.tasks.v1"

    init() {
        load()
    }

    var openTasks: [TaskItem] { tasks.filter { !$0.isDone } }
    var doneTasks: [TaskItem] { tasks.filter { $0.isDone } }

    func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        tasks.append(TaskItem(title: title))
        newTitle = ""
    }

    func toggle(_ task: TaskItem) {
        guard let i = tasks.firstIndex(of: task) else { return }
        tasks[i].isDone.toggle()
    }

    func delete(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TaskItem].self, from: data)
        else { return }
        tasks = decoded
    }
}
