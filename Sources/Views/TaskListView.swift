import SwiftUI

// Màn hình danh sách việc cần làm
struct TaskListView: View {
    @EnvironmentObject var vm: TaskListViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Chưa xong (\(vm.openTasks.count))") {
                    ForEach(vm.openTasks) { task in
                        taskRow(task)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { vm.openTasks[$0].id }
                        vm.tasks.removeAll { ids.contains($0.id) }
                    }
                }
                if !vm.doneTasks.isEmpty {
                    Section("Đã xong (\(vm.doneTasks.count))") {
                        ForEach(vm.doneTasks) { task in
                            taskRow(task)
                        }
                    }
                }
            }
            .navigationTitle("Việc cần làm")
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("Thêm việc mới...", text: $vm.newTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { vm.addTask() }
                    Button("Thêm") { vm.addTask() }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        Button {
            vm.toggle(task)
        } label: {
            HStack {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? .green : .secondary)
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TaskListView().environmentObject(TaskListViewModel())
}
