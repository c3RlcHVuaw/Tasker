import SwiftUI
import Combine
import UniformTypeIdentifiers
import PhotosUI

struct HomeView: View {
    @ObservedObject var store: TaskStore
    @State private var newTaskText = ""
    @State private var newPhotos: [Data] = []
    @State private var keyboardHeight: CGFloat = 0

    @State private var isSelectionMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showArchiveAllAlert = false
    @State private var currentPinnedIndex = 0
    @State private var scrollToTaskId: UUID?

    @Binding var selectedPhotoForPreview: Data?
    @Binding var isPhotoPreviewPresented: Bool
    
    var pinnedTasks: [TaskItem] {
        store.tasks.filter { $0.isPinned }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    // Список задач или пустое состояние
                    VStack(spacing: 0) {
                        // Pinned tasks header
                        if !pinnedTasks.isEmpty {
                            PinnedTasksHeader(
                                pinnedTasks: pinnedTasks,
                                currentIndex: $currentPinnedIndex,
                                onTaskSelected: { task in
                                    scrollToTaskId = task.id
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 12)
                        }
                        
                        if store.tasks.isEmpty {
                            ContentUnavailableView(
                                "Начните создавать задачи",
                                systemImage: "text.bubble",
                                description: Text("Напишите что-нибудь!")
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollViewReader { scrollProxy in
                                TaskListView(
                                    tasks: store.tasks,
                                    store: store,
                                    selectedPhotoForPreview: $selectedPhotoForPreview,
                                    isPhotoPreviewPresented: $isPhotoPreviewPresented,
                                    isSelectionMode: $isSelectionMode,
                                    selectedTasks: $selectedTasks
                                )
                                // выделяем место под кнопку «Отметить как выполненные»
                                .safeAreaInset(edge: .bottom) {
                                    Color.clear.frame(height: isSelectionMode ? 60 : 100)
                                }
                                .onChange(of: scrollToTaskId) { taskId in
                                    if let taskId = taskId {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            scrollProxy.scrollTo(taskId, anchor: .top)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onReceive(Publishers.keyboardHeightPublisher) { height in
                        withAnimation(.easeOut(duration: 0.2)) {
                            keyboardHeight = height
                        }
                    }

                    // Нижняя область: инпут или кнопка «Отметить как выполненные»
                    VStack {
                        Spacer()
                        if isSelectionMode {
                            Button("Отметить как выполненные") {
                                completeSelectedTasks()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        } else {
                            GlassInputField(
                                text: $newTaskText,
                                photos: $newPhotos,
                                onSubmit: addTask
                            )
                            .offset(y: keyboardHeight > 0 ? -(keyboardHeight - proxy.safeAreaInsets.bottom) : 0)
                        }
                    }
                    .zIndex(1)
                }
            }
            // Настройка тулбара
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Задачи")
                            .font(.headline)
                        Text("Всего \(store.tasks.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        Button {
                            showArchiveAllAlert = true
                        } label: {
                            Text("Закрыть все")
                        }
                        .foregroundColor(.red)
                    } else {
                        Button {
                            isSelectionMode = true
                        } label: {
                            Image(systemName: "checkmark.circle")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("Отмена") {
                            isSelectionMode = false
                            selectedTasks.removeAll()
                        }
                    }
                }
            }
            // Диалог подтверждения для архивации всех задач
            .alert("Переместить все задачи в архив?",
                   isPresented: $showArchiveAllAlert) {
                Button("Архивировать", role: .destructive) {
                    archiveAllTasks()
                    isSelectionMode = false
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все задачи будут перенесены в Архив.")
            }
        }
        .background(Color.clear)
    }

    private func addTask() {
        guard !newTaskText.trimmingCharacters(in: .whitespaces).isEmpty || !newPhotos.isEmpty else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            store.tasks.append(TaskItem(text: newTaskText, photos: newPhotos))
        }
        newTaskText = ""
        newPhotos = []
    }

    private func completeSelectedTasks() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            for id in selectedTasks {
                if let task = store.tasks.first(where: { $0.id == id }) {
                    store.archiveTask(task)
                }
            }
            selectedTasks.removeAll()
            isSelectionMode = false
        }
    }

    private func archiveAllTasks() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            for task in store.tasks {
                store.archiveTask(task)
            }
            selectedTasks.removeAll()
        }
    }
}

struct TaskListView: View {
    let tasks: [TaskItem]
    @ObservedObject var store: TaskStore
    @Binding var selectedPhotoForPreview: Data?
    @Binding var isPhotoPreviewPresented: Bool
    @Binding var isSelectionMode: Bool
    @Binding var selectedTasks: Set<UUID>

    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskBubbleView(
                    task: task,
                    store: store,
                    selectedPhotoForPreview: $selectedPhotoForPreview,
                    isPhotoPreviewPresented: $isPhotoPreviewPresented,
                    isSelectionMode: $isSelectionMode,
                    selectedTasks: $selectedTasks
                )
                .id(task.id)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct TaskBubbleView: View {
    let task: TaskItem
    @ObservedObject var store: TaskStore
    @Binding var selectedPhotoForPreview: Data?
    @Binding var isPhotoPreviewPresented: Bool
    @Binding var isSelectionMode: Bool
    @Binding var selectedTasks: Set<UUID>

    private let columns = [GridItem(.adaptive(minimum: 80))]

    var body: some View {
        HStack(alignment: .top) {
            // Чекбокс в режиме выбора
            if isSelectionMode {
                Button {
                    toggleSelection()
                } label: {
                    Image(systemName: selectedTasks.contains(task.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                // Вложения
                if let photos = task.photos, !photos.isEmpty {
                    Group {
                        switch photos.count {
                        case 1:
                            if let data = photos.first, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 220, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture {
                                        handleTapOnPhoto(data)
                                    }
                            }
                        case 2:
                            HStack(spacing: 8) {
                                ForEach(photos.prefix(2), id: \.self) { data in
                                    if let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 140, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onTapGesture {
                                                handleTapOnPhoto(data)
                                            }
                                    }
                                }
                            }
                        case 3:
                            HStack(spacing: 8) {
                                if let first = photos.first, let uiImage = UIImage(data: first) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 160, height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .onTapGesture {
                                            handleTapOnPhoto(first)
                                        }
                                }
                                VStack(spacing: 8) {
                                    ForEach(photos.dropFirst().prefix(2), id: \.self) { data in
                                        if let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 76)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .onTapGesture {
                                                    handleTapOnPhoto(data)
                                                }
                                        }
                                    }
                                }
                            }
                        default:
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(photos.prefix(6), id: \.self) { data in
                                    if let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .onTapGesture {
                                                handleTapOnPhoto(data)
                                            }
                                    }
                                }
                            }
                        }
                    }
                }

                // Текст задачи
                if !task.text.isEmpty {
                    HStack(spacing: 0) {
                        if task.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.trailing, 6)
                        }
                        
                        Text(task.text)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                }

                // Реакции
                if !task.reactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(task.reactions, id: \.self) { reaction in
                            Text(reaction)
                                .font(.system(size: 13))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 6)
                }

                // Индикатор выполнения
                if task.isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(selectedTasks.contains(task.id)
                          ? Color.accentColor.opacity(0.5)
                          : Color.accentColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .opacity(selectedTasks.contains(task.id) ? 1 : 0)
            )
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode { toggleSelection() }
        }
        .contextMenu {
            TaskContextMenu(
                task: task,
                store: store,
                selectedTasks: $selectedTasks,
                isSelectionMode: $isSelectionMode
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isSelectionMode {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        store.archiveTask(task)
                    }
                } label: {
                    Label("Архив", systemImage: "archivebox.fill")
                }
                .tint(.accentColor)
            }
        }
    }

    private func handleTapOnPhoto(_ data: Data) {
        if isSelectionMode {
            toggleSelection()
        } else {
            selectedPhotoForPreview = data
            isPhotoPreviewPresented = true
        }
    }

    private func toggleSelection() {
        if selectedTasks.contains(task.id) {
            selectedTasks.remove(task.id)
        } else {
            selectedTasks.insert(task.id)
        }
    }
}
