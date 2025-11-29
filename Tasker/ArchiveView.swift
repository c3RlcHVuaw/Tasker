import SwiftUI

struct ArchiveView: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack {
            if store.archivedTasks.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Архив пуст")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            } else {
                List {
                    ForEach(store.archivedTasks) { task in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(task.text)
                                .font(.body)
                            Text(task.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .swipeActions(edge: .leading) {
                            Button {
                                restore(task)
                            } label: {
                                Label("Восстановить", systemImage: "arrow.uturn.backward.circle.fill")
                            }
                            .tint(.green)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.white)
            }
        }
        .background(Color.white)
    }

    private func restore(_ task: TaskItem) {
        withAnimation {
            if let index = store.archivedTasks.firstIndex(of: task) {
                let restored = store.archivedTasks.remove(at: index)
                store.tasks.append(restored)
            }
        }
    }
}
