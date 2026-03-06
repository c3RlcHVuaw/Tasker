import SwiftUI

struct SearchResults: View {
    @ObservedObject var store: TaskStore
    @Binding var searchText: String

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
                ContentUnavailableView(
                    searchText.isEmpty ? "Начните поиск" : "Ничего не найдено",
                    systemImage: "magnifyingglass",
                    description: searchText.isEmpty ? Text("Введите запрос для поиска") : Text("Попробуйте другой запрос")
                )
            } else {
                GeometryReader { proxy in
                    List {
                        ForEach(filteredTasks) { task in
                            TaskBubbleView(
                                task: task,
                                containerWidth: proxy.size.width,
                                coordinateSpaceName: "searchResultsSpace",
                                store: store,
                                selectedPhotoForPreview: .constant(nil),
                                isPhotoPreviewPresented: .constant(false),
                                isSelectionMode: .constant(false),
                                selectedTasks: .constant(Set<UUID>())
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .coordinateSpace(name: "searchResultsSpace")
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.white)
                }
            }
        }
        .navigationTitle("Поиск")
    }
}
