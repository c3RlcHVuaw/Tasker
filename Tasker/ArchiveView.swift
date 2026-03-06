import SwiftUI

struct ArchiveView: View {
    @ObservedObject var store: TaskStore
    @Binding var selectedPhotoForPreview: Data?
    @Binding var isPhotoPreviewPresented: Bool

    private var stateAnimation: Animation {
        if #available(iOS 26.0, *) {
            return .smooth(duration: 0.22)
        } else {
            return .easeInOut(duration: 0.22)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
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
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        List {
                            ForEach(store.archivedTasks) { task in
                                VStack(alignment: .leading, spacing: 8) {
                                    if let photos = task.photos, !photos.isEmpty {
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                            ForEach(Array(photos.enumerated()), id: \.offset) { _, photoData in
                                                CachedDataImage(
                                                    data: photoData,
                                                    maxPixelSize: 80,
                                                    content: { image in
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 80, height: 80)
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                            .onTapGesture {
                                                                selectedPhotoForPreview = photoData
                                                                isPhotoPreviewPresented = true
                                                            }
                                                    },
                                                    placeholder: {
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(Color.secondary.opacity(0.15))
                                                            .frame(width: 80, height: 80)
                                                    }
                                                )
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
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(stateAnimation, value: store.archivedTasks.count)
                
                Spacer()
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
