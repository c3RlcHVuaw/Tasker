import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject var store: TaskStore
    @State private var newTaskText: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Контент
                if store.tasks.isEmpty {
                    Spacer()
                    EmptyStateView()
                    Spacer()
                } else {
                    TaskListView()
                }

                // Отступ снизу, чтобы табы не перекрывали контент
                Spacer().frame(height: 70)
            }
            .background(Color.white)

            // Плавающий инпут над клавиатурой
            VStack {
                Spacer()
                GlassInputField(
                    text: $newTaskText,
                    onSubmit: addTask
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 8)
                .padding(.bottom, keyboardHeight + 8)
                .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
        }
        .onReceive(Publishers.keyboardHeightPublisher) { height in
            keyboardHeight = height
        }
    }

    @State private var keyboardHeight: CGFloat = 0

    private func addTask() {
        guard !newTaskText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation {
            store.tasks.append(TaskItem(text: newTaskText))
        }
        newTaskText = ""
        focused = false
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 32))
                .foregroundColor(.blue.opacity(0.6))
            Text("Напишите что-нибудь!")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

struct TaskListView: View {
    var body: some View {
        List {
            Text("Пример задачи 1")
            Text("Пример задачи 2")
        }
        .scrollContentBackground(.hidden)
        .background(Color.white)
    }
}
