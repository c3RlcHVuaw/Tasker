import SwiftUI

struct SearchView: View {
    @ObservedObject var store: TaskStore
    @Binding var selectedPhotoForPreview: Data?
    @Binding var isPhotoPreviewPresented: Bool
    @Binding var searchText: String
    @State private var selectedReactionFilter: String?
    @FocusState private var isSearchFocused: Bool
    @State private var dragOffset: CGFloat = 0
    
    var filteredTasks: [TaskItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var tasks = store.tasks + store.archivedTasks
        
        // Фильтр по текстовому поиску
        if !query.isEmpty {
            tasks = tasks.filter {
                $0.text.localizedCaseInsensitiveContains(query)
            }
        }
        
        // Фильтр по реакциям
        if let reaction = selectedReactionFilter {
            tasks = tasks.filter { $0.reactions.contains(reaction) }
        }
        
        return tasks
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Список результатов поиска
                if filteredTasks.isEmpty && (!searchText.isEmpty || selectedReactionFilter != nil) {
                    ContentUnavailableView(
                        "Ничего не найдено",
                        systemImage: "magnifyingglass",
                        description: Text("Попробуйте другой поисковый запрос или реакцию")
                    )
                } else if filteredTasks.isEmpty {
                    ContentUnavailableView(
                        "Поиск задач",
                        systemImage: "magnifyingglass",
                        description: Text("Введите текст для поиска")
                    )
                } else {
                    List(filteredTasks) { task in
                        TaskBubbleView(
                            task: task,
                            store: store,
                            selectedPhotoForPreview: $selectedPhotoForPreview,
                            isPhotoPreviewPresented: $isPhotoPreviewPresented,
                            isSelectionMode: .constant(false),
                            selectedTasks: .constant(Set<UUID>())
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                Spacer()
            }
            .background(Color.clear)
            
            // Затемнение как на главной странице
            VStack(spacing: 0) {
                // Градиент затемнения сверху
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.black.opacity(0.15), location: 0),
                        .init(color: Color.black.opacity(0), location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
                
                // Контент поиска
                VStack(spacing: 12) {
                    // Реакции для фильтрации - нативные табы
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: { selectedReactionFilter = nil }) {
                                Text("Все")
                                    .font(.system(.caption2, design: .rounded))
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .foregroundColor(selectedReactionFilter == nil ? .white : .primary)
                                    .frame(height: 32)
                                    .background(
                                        selectedReactionFilter == nil ?
                                        Color.accentColor :
                                        Color.clear
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Group {
                                            if selectedReactionFilter == nil {
                                                Capsule()
                                                    .strokeBorder(Color.clear)
                                            } else {
                                                if #available(iOS 26.0, *) {
                                                    Capsule()
                                                        .fill(.ultraThinMaterial)
                                                } else {
                                                    Capsule()
                                                        .fill(Color(UIColor.secondarySystemBackground))
                                                }
                                            }
                                        }
                                    )
                            }
                            
                            ForEach(reactionEmojis, id: \.self) { emoji in
                                Button(action: { selectedReactionFilter = emoji }) {
                                    Text(emoji)
                                        .font(.system(size: 16))
                                        .frame(width: 36, height: 32)
                                        .background(
                                            selectedReactionFilter == emoji ?
                                            Color.accentColor.opacity(0.25) :
                                            Color.clear
                                        )
                                        .clipShape(Capsule())
                                        .overlay(
                                            Group {
                                                if #available(iOS 26.0, *) {
                                                    Capsule()
                                                        .fill(.ultraThinMaterial)
                                                        .opacity(selectedReactionFilter == emoji ? 0 : 0.7)
                                                } else {
                                                    Capsule()
                                                        .fill(Color(UIColor.secondarySystemBackground))
                                                        .opacity(selectedReactionFilter == emoji ? 0 : 0.7)
                                                }
                                            }
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    
                    // Нативный поисковый инпут с drag-to-dismiss
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray.opacity(0.6))
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.leading, 4)
                        
                        TextField("Поиск", text: $searchText)
                            .font(.system(.body, design: .default))
                            .textFieldStyle(.plain)
                            .focused($isSearchFocused)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .font(.system(size: 15))
                            }
                            .padding(.trailing, 4)
                        }
                    }
                    .frame(height: 36)
                    .padding(.horizontal, 10)
                    .background(
                        Group {
                            if #available(iOS 26.0, *) {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .glassEffect(.regular, in: Capsule())
                            } else {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            }
                        }
                    )
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .offset(y: dragOffset * 0.5)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 60 {
                                    isSearchFocused = false
                                }
                                dragOffset = 0
                            }
                    )
                }
                .padding(.top, 10)
            }
            .background(Color.clear)
        }
    }
}

#Preview {
    SearchView(
        store: TaskStore(),
        selectedPhotoForPreview: .constant(nil),
        isPhotoPreviewPresented: .constant(false),
        searchText: .constant("")
    )
}
