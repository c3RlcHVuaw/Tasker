import Foundation

// MARK: - Реакции на сообщения
let reactionEmojis = ["⭐", "✏️", "💡", "📅", "🔥", "❤️", "❓", "🗑️"]

// MARK: - Модель задачи
struct TaskItem: Identifiable, Equatable, Codable {
    let id: UUID
    var text: String
    var date: Date
    var isDone: Bool
    var photos: [Data]?
    var reactions: [String] = []
    var isPinned: Bool = false
    var repliedTo: UUID? = nil

    init(id: UUID = UUID(), text: String, date: Date = Date(), isDone: Bool = false, photos: [Data]? = nil, reactions: [String] = [], isPinned: Bool = false, repliedTo: UUID? = nil) {
        self.id = id
        self.text = text
        self.date = date
        self.isDone = isDone
        self.photos = photos
        self.reactions = reactions
        self.isPinned = isPinned
        self.repliedTo = repliedTo
    }
}
