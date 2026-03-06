import Foundation

enum TaskRecurrence: String, CaseIterable, Codable, Sendable {
    case none
    case daily
    case weekly
    case monthly

    var title: String {
        switch self {
        case .none:
            return "Без повтора"
        case .daily:
            return "Ежедневно"
        case .weekly:
            return "Еженедельно"
        case .monthly:
            return "Ежемесячно"
        }
    }

    var shortTitle: String {
        switch self {
        case .none:
            return "Без повтора"
        case .daily:
            return "Ежедн."
        case .weekly:
            return "Еженед."
        case .monthly:
            return "Ежемес."
        }
    }
}

// MARK: - Модель задачи
struct TaskItem: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var text: String
    var date: Date
    var isDone: Bool
    var photos: [Data]?
    var reactions: [String]
    var isPinned: Bool
    var recurrence: TaskRecurrence

    init(
        id: UUID = UUID(),
        text: String,
        date: Date = Date(),
        isDone: Bool = false,
        photos: [Data]? = nil,
        reactions: [String] = [],
        isPinned: Bool = false,
        recurrence: TaskRecurrence = .none
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.isDone = isDone
        self.photos = photos
        self.reactions = reactions
        self.isPinned = isPinned
        self.recurrence = recurrence
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case date
        case isDone
        case photos
        case reactions
        case isPinned
        case recurrence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        date = try container.decode(Date.self, forKey: .date)
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        photos = try container.decodeIfPresent([Data].self, forKey: .photos)
        reactions = try container.decodeIfPresent([String].self, forKey: .reactions) ?? []
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        recurrence = try container.decodeIfPresent(TaskRecurrence.self, forKey: .recurrence) ?? .none
    }
}

let reactionEmojis = ["👍", "❤️", "🔥", "👏", "🤔", "✅", "🚀", "👀", "😊", "💡"]
