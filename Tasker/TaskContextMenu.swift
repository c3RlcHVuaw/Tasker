import SwiftUI

struct TaskContextMenu: View {
    let task: TaskItem
    let store: TaskStore
    @Binding var selectedTasks: Set<UUID>
    @Binding var isSelectionMode: Bool
    @State private var selectedReaction: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Reactions section with horizontal scroll
            VStack(spacing: 8) {
                Text("Реакции")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(reactionEmojis, id: \.self) { emoji in
                            Button(action: {
                                addReaction(emoji)
                            }) {
                                Text(emoji)
                                    .font(.system(size: 24))
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
            
            Divider()
            
            // Main actions - no dividers between them
            VStack(spacing: 0) {
                MenuButton(
                    icon: "arrowshape.turn.up.left",
                    label: "Ответить",
                    showDivider: false,
                    action: { }
                )
                
                MenuButton(
                    icon: "doc.on.doc",
                    label: "Скопировать",
                    showDivider: false,
                    action: {
                        UIPasteboard.general.string = task.text
                    }
                )
                
                MenuButton(
                    icon: "pin",
                    label: "Закрепить",
                    showDivider: false,
                    action: {
                        togglePin()
                    }
                )
                
                MenuButton(
                    icon: "archivebox",
                    label: "Архивировать",
                    tintColor: .red,
                    showDivider: false,
                    action: {
                        if let updatedTask = store.tasks.first(where: { $0.id == task.id }) {
                            store.archiveTask(updatedTask)
                        }
                    }
                )
            }
            
            Divider()
            
            // Selection action
            VStack(spacing: 0) {
                MenuButton(
                    icon: "checkmark.circle",
                    label: "Выбрать",
                    showDivider: false,
                    action: {
                        if selectedTasks.contains(task.id) {
                            selectedTasks.remove(task.id)
                        } else {
                            selectedTasks.insert(task.id)
                        }
                        isSelectionMode = true
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func addReaction(_ emoji: String) {
        if let index = store.tasks.firstIndex(where: { $0.id == task.id }) {
            if store.tasks[index].reactions.contains(emoji) {
                store.tasks[index].reactions.removeAll { $0 == emoji }
            } else {
                store.tasks[index].reactions.append(emoji)
            }
        }
    }
    
    private func togglePin() {
        if let index = store.tasks.firstIndex(where: { $0.id == task.id }) {
            store.tasks[index].isPinned.toggle()
        }
    }
}

struct MenuButton: View {
    let icon: String
    let label: String
    var tintColor: Color = .accentColor
    var showDivider: Bool = true
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(tintColor)
                        .frame(width: 24)
                    
                    Text(label)
                        .foregroundColor(.primary)
                        .font(.system(.body, design: .rounded))
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if showDivider {
                Divider()
                    .padding(.vertical, 0)
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
