import SwiftUI

struct SearchResults: View {
    @ObservedObject var store: TaskStore
    @Binding var searchText: String   // ← принимает $searchText из ContentView

    var filteredTasks: [TaskItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return store.tasks
        } else {
            return store.tasks.filter { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            if filteredTasks.isEmpty {
                ContentUnavailableView("Ничего не найдено",
                                        systemImage: "magnifyingglass")
            } else {
                List(filteredTasks) { task in
                    Label(task.text, systemImage: task.isDone ? "checkmark.circle.fill" : "circle")
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Поиск")
    }
}
