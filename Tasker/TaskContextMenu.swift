import SwiftUI

struct TaskContextMenu: View {
    let task: TaskItem
    let store: TaskStore
    @Binding var selectedTasks: Set<UUID>
    @Binding var isSelectionMode: Bool

    private var mutationAnimation: Animation {
        AppAnimations.standard
    }
    
    @ViewBuilder
    var body: some View {
        Menu("Реакция") {
            ForEach(reactionEmojis, id: \.self) { emoji in
                Button {
                    addReaction(emoji)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(reactionColor(for: emoji))
                        Text(emoji)
                    }
                }
            }
        }

        Button {
            UIPasteboard.general.string = task.text
        } label: {
            Label("Скопировать", systemImage: "doc.on.doc")
        }

        Button {
            // Placeholder for future threaded replies.
        } label: {
            Label("Ответить", systemImage: "arrowshape.turn.up.left")
        }

        Button {
            togglePin()
        } label: {
            Label(task.isPinned ? "Открепить" : "Закрепить", systemImage: "pin")
        }

        Menu {
            ForEach(TaskRecurrence.allCases, id: \.rawValue) { item in
                Button {
                    setRecurrence(item)
                } label: {
                    HStack {
                        Text(item.title)
                        if task.recurrence == item {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Повтор: \(task.recurrence.title)", systemImage: "repeat")
        }

        Button(role: .destructive) {
            if let updatedTask = store.tasks.first(where: { $0.id == task.id }) {
                withAnimation(mutationAnimation) {
                    store.archiveTask(updatedTask)
                }
            }
        } label: {
            Label("Архивировать", systemImage: "archivebox")
        }

        Button {
            withAnimation(mutationAnimation) {
                if selectedTasks.contains(task.id) {
                    selectedTasks.remove(task.id)
                } else {
                    selectedTasks.insert(task.id)
                }
                isSelectionMode = true
            }
        } label: {
            Label("Выбрать", systemImage: "checkmark.circle")
        }
    }
    
    private func addReaction(_ emoji: String) {
        if let index = store.tasks.firstIndex(where: { $0.id == task.id }) {
            withAnimation(mutationAnimation) {
                if store.tasks[index].reactions.contains(emoji) {
                    store.tasks[index].reactions.removeAll { $0 == emoji }
                } else {
                    store.tasks[index].reactions.append(emoji)
                }
            }
        }
    }
    
    private func togglePin() {
        if let index = store.tasks.firstIndex(where: { $0.id == task.id }) {
            withAnimation(mutationAnimation) {
                store.tasks[index].isPinned.toggle()
            }
        }
    }

    private func setRecurrence(_ recurrence: TaskRecurrence) {
        if let index = store.tasks.firstIndex(where: { $0.id == task.id }) {
            withAnimation(mutationAnimation) {
                store.tasks[index].recurrence = recurrence
            }
        }
    }

    private func reactionColor(for emoji: String) -> Color {
        switch emoji {
        case "👍": return .blue
        case "❤️": return .red
        case "🔥": return .orange
        case "👏": return .green
        case "🤔": return .yellow
        case "✅": return .mint
        case "🚀": return .indigo
        case "👀": return .teal
        case "😊": return .pink
        case "💡": return .purple
        default: return .secondary
        }
    }

}

#Preview {
    TaskContextMenu(
        task: TaskItem(text: "Test task"),
        store: TaskStore(),
        selectedTasks: .constant(Set()),
        isSelectionMode: .constant(false)
    )
}
