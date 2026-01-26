import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject var store: TaskStore
    @State private var newTaskText: String = ""
    @FocusState private var focused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Контент
            if store.tasks.isEmpty {
                ContentUnavailableView(
                    "Начните создавать задачи",
                    systemImage: "text.bubble",
                    description: Text("Напишите что-нибудь!")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            } else {
                TaskListView(store: store)
                    .padding(.bottom, keyboardHeight > 0 ? 120 : 70)
            }

            // Плавающий инпут над клавиатурой
            GlassInputField(
                text: $newTaskText,
                onSubmit: addTask
            )
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 8 : 8)
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
        }
        .background(Color.white)
        .onReceive(Publishers.keyboardHeightPublisher) { height in
            keyboardHeight = height
        }
    }

    private func addTask() {
        guard !newTaskText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            store.tasks.append(TaskItem(text: newTaskText))
        }
        newTaskText = ""
        focused = false
    }
}

struct TaskListView: View {
    @ObservedObject var store: TaskStore
    
    var body: some View {
        List {
            ForEach(store.tasks) { task in
                TaskBubbleView(task: task, store: store)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.white)
    }
}

struct TaskBubbleView: View {
    let task: TaskItem
    @ObservedObject var store: TaskStore
    
    var body: some View {
        HStack {
            Spacer()
            
            // Бабл-сообщение справа
            HStack(alignment: .top, spacing: 8) {
                Text(task.text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                
                if task.isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(red: 0.0, green: 0.478, blue: 1.0))
                        .glassEffect(.regular.tint(Color(red: 0.0, green: 0.478, blue: 1.0)).interactive(), in: .rect(cornerRadius: 18))
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(red: 0.0, green: 0.478, blue: 1.0))
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    store.archiveTask(task)
                }
            } label: {
                Label("Архив", systemImage: "archivebox.fill")
            }
            .tint(.blue)
        }
    }
}
