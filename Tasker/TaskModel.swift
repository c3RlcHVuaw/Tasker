import Foundation
import Combine

// MARK: - Модель задачи
struct TaskItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    var date: Date
    var isDone: Bool

    init(id: UUID = UUID(), text: String, date: Date = Date(), isDone: Bool = false) {
        self.id = id
        self.text = text
        self.date = date
        self.isDone = isDone
    }
}

// MARK: - Хранилище задач
@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var archivedTasks: [TaskItem] = []
}
