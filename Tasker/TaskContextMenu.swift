import SwiftUI

struct TaskContextMenu: View {
    let task: TaskItem
    let store: TaskStore
    @Binding var selectedTasks: Set<UUID>
    @Binding var isSelectionMode: Bool

    private var mutationAnimation: Animation {
        if #available(iOS 26.0, *) {
            return .snappy(duration: 0.24, extraBounce: 0.07)
        } else {
            return .spring(response: 0.30, dampingFraction: 0.84)
        }
    }
    
    @ViewBuilder
    var body: some View {
        Menu("Реакция") {
            ForEach(reactionEmojis, id: \.self) { emoji in
                Button(emoji) {
                    addReaction(emoji)
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
}

#Preview {
    TaskContextMenu(
        task: TaskItem(text: "Test task"),
        store: TaskStore(),
        selectedTasks: .constant(Set()),
        isSelectionMode: .constant(false)
    )
}
