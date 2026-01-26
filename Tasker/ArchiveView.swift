import SwiftUI

struct ArchiveView: View {
    @ObservedObject var store: TaskStore
    @Binding var selectedPhotoForPreview: Data?
    @Binding var isPhotoPreviewPresented: Bool

    private let columns = [GridItem(.adaptive(minimum: 80))]

    var body: some View {
        NavigationStack {
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
                    .background(Color.clear)
                } else {
                    List {
                        ForEach(store.archivedTasks) { task in
                            VStack(alignment: .leading, spacing: 8) {
                                if let photos = task.photos, !photos.isEmpty {
                                    LazyVGrid(columns: columns, spacing: 8) {
                                        ForEach(photos, id: \.self) { photoData in
                                            if let uiImage = UIImage(data: photoData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .onTapGesture {
                                                        selectedPhotoForPreview = photoData
                                                        isPhotoPreviewPresented = true
                                                    }
                                            }
                                        }
                                    }
                                }
                                if !task.text.isEmpty {
                                    Text(task.text)
                                        .font(.body)
                                }
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
                    .contentShape(Rectangle())
                }
            }
            .navigationTitle("Архив")
            .background(Color.clear)
        }
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
