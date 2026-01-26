import Foundation

// MARK: - Модель задачи
struct TaskItem: Identifiable, Equatable, Codable {
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
