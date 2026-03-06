import SwiftUI
import Combine
import UniformTypeIdentifiers
import PhotosUI

struct TaskBubbleFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct HomeView: View {
    @ObservedObject var store: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccentColor) private var appAccentColor
    @AppStorage("settings_enable_haptics") private var enableHaptics = true
    @AppStorage("settings_enable_rich_animations") private var enableRichAnimations = true
    @State private var keyboardHeight: CGFloat = 0

    @State private var isSelectionMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showArchiveAllAlert = false
    @State private var currentPinnedIndex = 0
    @State private var scrollToTaskId: UUID?
    @State private var didPerformInitialBottomScroll = false
    @State private var selectedReaction: String?
    @State private var isReactionSlideForward = true
    @State private var contextMenuTask: TaskItem?
    @State private var isContextMenuPresented = false
    @State private var isContextMenuContentVisible = false
    @State private var contextMenuPresentationID = UUID()
    @State private var contextMenuAnimationTask: Task<Void, Never>?
    @State private var bubbleFrames: [UUID: CGRect] = [:]
    @State private var isAppSettingsPresented = false
    @AppStorage(AppPreferenceKeys.premiumUnlocked) private var isPremiumUnlocked = false
    @AppStorage(AppPreferenceKeys.chatBackgroundStyle) private var chatBackgroundStyleRawValue = ChatBackgroundStyle.system.rawValue
    @AppStorage(AppPreferenceKeys.chatBackgroundCustomImagePath) private var chatBackgroundCustomImagePath = ""

    @Binding var selectedPhotoForPreview: Data?
    @Binding var isPhotoPreviewPresented: Bool

    private var mutationAnimation: Animation {
        guard enableRichAnimations else {
            return .linear(duration: 0.01)
        }
        return AppAnimations.standard
    }

    private var stateTransition: AnyTransition {
        .opacity.combined(with: .move(edge: .bottom))
    }

    private var effectiveChatBackgroundStyle: ChatBackgroundStyle {
        guard isPremiumUnlocked else { return .system }
        return ChatBackgroundStyle(rawValue: chatBackgroundStyleRawValue) ?? .system
    }
    
    var pinnedTasks: [TaskItem] {
        store.tasks.filter { $0.isPinned }
    }

    var availableReactions: [String] {
        usedReactions(from: store.tasks)
    }

    var filteredTasks: [TaskItem] {
        guard let selectedReaction else { return store.tasks }
        return store.tasks.filter { $0.reactions.contains(selectedReaction) }
    }

    private var reactionSelectionID: String {
        selectedReaction ?? "__all__"
    }

    private var reactionSlideTransition: AnyTransition {
        if isReactionSlideForward {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private enum ListContentState: Equatable {
        case empty
        case filteredEmpty
        case list
    }

    private var listContentState: ListContentState {
        if store.tasks.isEmpty { return .empty }
        if filteredTasks.isEmpty { return .filteredEmpty }
        return .list
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    ChatBackgroundView(
                        style: effectiveChatBackgroundStyle,
                        customImagePath: chatBackgroundCustomImagePath
                    )
                    .allowsHitTesting(false)

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
                            .padding(.top, 0)
                            .padding(.bottom, availableReactions.isEmpty ? 12 : 10)
                        }

                        if !availableReactions.isEmpty {
                            SearchReactionChipsBar(
                                reactions: availableReactions,
                                selectedReaction: $selectedReaction,
                                onDirectionResolved: { isForward in
                                    isReactionSlideForward = isForward
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                        }
                        
                        Group {
                            if store.tasks.isEmpty {
                                ContentUnavailableView(
                                    "Начните создавать задачи",
                                    systemImage: "text.bubble",
                                    description: Text("Напишите что-нибудь!")
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(stateTransition)
                            } else if filteredTasks.isEmpty {
                                ContentUnavailableView(
                                    "Ничего не найдено",
                                    systemImage: "line.3.horizontal.decrease.circle",
                                    description: Text("Для выбранной реакции задач нет")
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(stateTransition)
                            } else {
                                ScrollViewReader { scrollProxy in
                                    GeometryReader { listProxy in
                                    TaskListView(
                                        tasks: filteredTasks,
                                        containerWidth: listProxy.size.width,
                                        coordinateSpaceName: "homeSpace",
                                        store: store,
                                        selectedPhotoForPreview: $selectedPhotoForPreview,
                                        isPhotoPreviewPresented: $isPhotoPreviewPresented,
                                        isSelectionMode: $isSelectionMode,
                                            selectedTasks: $selectedTasks,
                                            onContextMenuRequested: openMessageContextMenu
                                        )
                                        .id(reactionSelectionID)
                                        .transition(reactionSlideTransition)
                                        .contentShape(Rectangle())
                                        .simultaneousGesture(
                                            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                                                .onEnded { value in
                                                    handleChatFilterSwipe(value, listWidth: listProxy.size.width)
                                                }
                                        )
                                        // выделяем место под кнопку «Отметить как выполненные»
                                        .safeAreaInset(edge: .bottom) {
                                            Color.clear.frame(height: isSelectionMode ? 60 : 100)
                                        }
                                        .onChange(of: scrollToTaskId) { _, taskId in
                                            if let taskId {
                                                withAnimation(AppAnimations.standard) {
                                                    scrollProxy.scrollTo(taskId, anchor: .top)
                                                }
                                            }
                                        }
                                        .onAppear {
                                            scrollToBottomIfNeeded(using: scrollProxy)
                                        }
                                        .onChange(of: filteredTasks.map(\.id)) { _, _ in
                                            scrollToBottomIfNeeded(using: scrollProxy)
                                        }
                                    }
                                }
                                .transition(stateTransition)
                            }
                        }
                        .contentTransition(.opacity)
                        .animation(mutationAnimation, value: listContentState)
                    }
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .coordinateSpace(name: "homeSpace")
                    .onPreferenceChange(TaskBubbleFramePreferenceKey.self) { bubbleFrames = $0 }
                    .blur(radius: isContextMenuPresented ? 10 : 0)
                    .allowsHitTesting(!isContextMenuPresented)
                    .onReceive(Publishers.keyboardHeightPublisher) { height in
                        withAnimation(AppAnimations.fade) {
                            keyboardHeight = height
                        }
                    }
                    .onChange(of: availableReactions) { _, newValue in
                        if let selectedReaction, !newValue.contains(selectedReaction) {
                            self.selectedReaction = nil
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
                            .tint(appAccentColor)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .transition(stateTransition)
                        } else {
                            GlassInputField(
                                onSubmit: addTask
                            )
                            .offset(y: keyboardHeight > 0 ? -(keyboardHeight - proxy.safeAreaInsets.bottom) : 0)
                            .transition(stateTransition)
                        }
                    }
                    .opacity(isContextMenuPresented ? 0 : 1)
                    .allowsHitTesting(!isContextMenuPresented)
                    .zIndex(1)
                    .animation(mutationAnimation, value: isSelectionMode)

                    if let task = contextMenuTask {
                        messageContextOverlay(
                            for: task,
                            isOverlayPresented: isContextMenuPresented,
                            isContentPresented: isContextMenuContentVisible
                        )
                            .zIndex(2)
                    }
                }
                .overlay(alignment: .top) {
                    topAreaShade
                        .opacity(isContextMenuPresented ? 0 : 1)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbar(isContextMenuPresented ? .hidden : .visible, for: .tabBar)
            .toolbar(isContextMenuPresented ? .hidden : .visible, for: .navigationBar)
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
                    } else {
                        appMenu
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
            .onDisappear {
                contextMenuAnimationTask?.cancel()
            }
            .sheet(isPresented: $isAppSettingsPresented) {
                AppSettingsSheet(store: store)
            }
        }
    }

    private var appMenu: some View {
        Menu {
            Button {
                isAppSettingsPresented = true
            } label: {
                Label("Настройки приложения", systemImage: "gearshape")
            }

            Section("Аккаунт") {
                Text("Вход через Apple ID временно отключен")
                    .foregroundStyle(.secondary)
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 24))
                .foregroundStyle(.primary)
        }
    }

    private var topAreaShade: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(colorScheme == .dark ? 0.20 : 0.10),
                Color.clear
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 180)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func messageContextOverlay(
        for task: TaskItem,
        isOverlayPresented: Bool,
        isContentPresented: Bool
    ) -> some View {
        GeometryReader { proxy in
            let overlaySize = proxy.size
            let sideInset = 18.0
            let topInset = max(58.0, proxy.safeAreaInsets.top + 8.0)
            let bottomInset = max(22.0, proxy.safeAreaInsets.bottom + 8.0)
            let frame = bubbleFrames[task.id] ?? CGRect(
                x: overlaySize.width * 0.30,
                y: overlaySize.height * 0.34,
                width: overlaySize.width * 0.68,
                height: 68
            )
            let actionsBaseHeight = IMessageActionsCard.baseHeight
            let focusedBubbleWidth = min(frame.width, overlaySize.width - sideInset * 2)
            let focusedBubbleHeight = max(frame.height, 82.0)
            let focusedBubbleX = max(
                focusedBubbleWidth / 2 + sideInset,
                min(frame.midX, overlaySize.width - focusedBubbleWidth / 2 - sideInset)
            )
            let focusedBubbleYMin = topInset + 140.0
            let focusedBubbleYMax = max(
                focusedBubbleYMin,
                overlaySize.height - bottomInset - (actionsBaseHeight * 0.72)
            )
            let focusedBubbleY = max(focusedBubbleYMin, min(frame.midY, focusedBubbleYMax))
            let focusedBubbleFrame = CGRect(
                x: focusedBubbleX - focusedBubbleWidth / 2,
                y: focusedBubbleY - focusedBubbleHeight / 2,
                width: focusedBubbleWidth,
                height: focusedBubbleHeight
            )

            let reactionWidth = min(320.0, overlaySize.width - sideInset * 2)
            let reactionHalf = reactionWidth / 2
            let reactionX = max(
                reactionHalf + sideInset,
                min(focusedBubbleFrame.midX, overlaySize.width - reactionHalf - sideInset)
            )
            let reactionsIntrinsicWidth = CGFloat(reactionEmojis.count) * 50 + 36
            let needsReactionScroll = reactionsIntrinsicWidth > reactionWidth

            let menuWidth = min(320.0, overlaySize.width - sideInset * 2)
            let menuX = max(
                menuWidth / 2 + sideInset,
                min(focusedBubbleFrame.midX, overlaySize.width - menuWidth / 2 - sideInset)
            )
            let reactionBlockHeight = IMessageReactionsBar.visualHeight
            let gapAfterReactions = 6.0
            let gapBeforeMenu = 8.0
            let tailToBubbleGap = 0.0
            let availableHeight = overlaySize.height - topInset - bottomInset - 16.0
            let fullGroupHeight = reactionBlockHeight + tailToBubbleGap + focusedBubbleHeight + gapBeforeMenu + actionsBaseHeight
            let menuDisplayHeight = fullGroupHeight <= availableHeight
                ? actionsBaseHeight
                : max(168.0, availableHeight - (reactionBlockHeight + tailToBubbleGap + focusedBubbleHeight + gapBeforeMenu))
            let isMenuScrollable = menuDisplayHeight < actionsBaseHeight

            let reactionCenterYOffset = 28.0
            let desiredGroupTop = frame.midY - (reactionCenterYOffset + gapAfterReactions + focusedBubbleHeight / 2)
            let groupHeight = reactionBlockHeight + tailToBubbleGap + focusedBubbleHeight + gapBeforeMenu + menuDisplayHeight
            let minGroupTop = topInset + 6.0
            let maxGroupTop = overlaySize.height - bottomInset - groupHeight - 6.0
            let groupTop = max(minGroupTop, min(desiredGroupTop, maxGroupTop))

            let reactionY = groupTop + reactionCenterYOffset
            let finalBubbleY = groupTop + reactionBlockHeight + tailToBubbleGap + focusedBubbleHeight / 2
            let finalBubbleFrame = CGRect(
                x: focusedBubbleFrame.minX,
                y: finalBubbleY - focusedBubbleHeight / 2,
                width: focusedBubbleWidth,
                height: focusedBubbleHeight
            )
            let menuTop = finalBubbleFrame.maxY + gapBeforeMenu
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Color.black.opacity(colorScheme == .dark ? 0.26 : 0.14)
                    )
                    .ignoresSafeArea()
                    .opacity(isOverlayPresented ? 1 : 0)
                    .onTapGesture {
                        closeMessageContextMenu()
                    }

                ContextFocusedTaskBubble(task: task)
                    .frame(width: finalBubbleFrame.width, height: finalBubbleFrame.height, alignment: .trailing)
                    .position(x: finalBubbleFrame.midX, y: finalBubbleFrame.midY)
                    .scaleEffect(isContentPresented ? 1 : 0.97, anchor: .trailing)
                    .opacity(isContentPresented ? 1 : 0)

                IMessageReactionsBar(
                    reactions: reactionEmojis,
                    selectedReactions: Set(task.reactions),
                    allowsScroll: needsReactionScroll,
                    onTap: { emoji in
                        toggleReaction(emoji, for: task.id)
                        closeMessageContextMenu()
                    }
                )
                .frame(width: reactionWidth)
                .position(x: reactionX, y: reactionY)
                .offset(y: isContentPresented ? 0 : 10)
                .opacity(isContentPresented ? 1 : 0)
                .id(contextMenuPresentationID)

                IMessageActionsCard(
                    task: task,
                    maxHeight: menuDisplayHeight,
                    isScrollable: isMenuScrollable,
                    onReply: { closeMessageContextMenu() },
                    onCopy: {
                        UIPasteboard.general.string = task.text
                        closeMessageContextMenu()
                    },
                    onPinToggle: {
                        togglePin(for: task.id)
                        closeMessageContextMenu()
                    },
                    onRecurrenceChange: { recurrence in
                        setRecurrence(recurrence, for: task.id)
                        closeMessageContextMenu()
                    },
                    onArchive: {
                        if let current = store.tasks.first(where: { $0.id == task.id }) {
                            withAnimation(mutationAnimation) {
                                store.archiveTask(current)
                            }
                        }
                        closeMessageContextMenu()
                    },
                    onSelect: {
                        withAnimation(mutationAnimation) {
                            selectedTasks.insert(task.id)
                            isSelectionMode = true
                        }
                        closeMessageContextMenu()
                    }
                )
                .frame(width: menuWidth)
                .position(x: menuX, y: menuTop + menuDisplayHeight / 2)
                .offset(y: isContentPresented ? 0 : 14)
                .scaleEffect(isContentPresented ? 1 : 0.985, anchor: .top)
                .opacity(isContentPresented ? 1 : 0)
                .id(contextMenuPresentationID)
            }
        }
        .transition(.opacity)
    }

    private func openMessageContextMenu(_ task: TaskItem) {
        guard !isSelectionMode else { return }
        impact(.medium)
        contextMenuAnimationTask?.cancel()
        contextMenuPresentationID = UUID()
        isContextMenuPresented = false
        isContextMenuContentVisible = false
        if let updated = store.tasks.first(where: { $0.id == task.id }) {
            contextMenuTask = updated
        } else {
            contextMenuTask = task
        }
        withAnimation(AppAnimations.fade) {
            isContextMenuPresented = true
        }
        let openID = contextMenuPresentationID
        contextMenuAnimationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled, openID == contextMenuPresentationID else { return }
            withAnimation(AppAnimations.menuPresent) {
                isContextMenuContentVisible = true
            }
        }
    }

    private func closeMessageContextMenu() {
        impact(.light)
        contextMenuAnimationTask?.cancel()
        let closingID = contextMenuPresentationID
        withAnimation(AppAnimations.menuDismiss) {
            isContextMenuContentVisible = false
        }
        contextMenuAnimationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 70_000_000)
            guard !Task.isCancelled, closingID == contextMenuPresentationID else { return }
            withAnimation(AppAnimations.fade) {
                isContextMenuPresented = false
            }

            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled, closingID == contextMenuPresentationID else { return }
            contextMenuTask = nil
        }
    }

    private func toggleReaction(_ emoji: String, for taskID: UUID) {
        guard let index = store.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        withAnimation(mutationAnimation) {
            if store.tasks[index].reactions.contains(emoji) {
                store.tasks[index].reactions.removeAll { $0 == emoji }
            } else {
                store.tasks[index].reactions.append(emoji)
            }
        }
    }

    private func togglePin(for taskID: UUID) {
        guard let index = store.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        withAnimation(mutationAnimation) {
            store.tasks[index].isPinned.toggle()
        }
    }

    private func setRecurrence(_ recurrence: TaskRecurrence, for taskID: UUID) {
        guard let index = store.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        withAnimation(mutationAnimation) {
            store.tasks[index].recurrence = recurrence
        }
    }

    private func addTask(text: String, photos: [Data], recurrence: TaskRecurrence) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty else { return }
        let addedPhotosCount = photos.count
        let assignedReactions = selectedReaction.map { [$0] } ?? []
        PerformanceTelemetry.measure("addTask") {
            withAnimation(AppAnimations.standard) {
                store.tasks.append(
                    TaskItem(
                        text: text,
                        photos: photos,
                        reactions: assignedReactions,
                        recurrence: recurrence
                    )
                )
            }
        }
        PerformanceTelemetry.countEvent("addTask.photosCount", count: addedPhotosCount)
    }

    private func completeSelectedTasks() {
        let selectedCount = selectedTasks.count
        PerformanceTelemetry.measure("completeSelectedTasks") {
            withAnimation(AppAnimations.standard) {
                store.archiveTasks(ids: selectedTasks)
                selectedTasks.removeAll()
                isSelectionMode = false
            }
        }
        PerformanceTelemetry.countEvent("completeSelectedTasks.count", count: selectedCount)
    }

    private func archiveAllTasks() {
        let totalCount = store.tasks.count
        PerformanceTelemetry.measure("archiveAllTasks") {
            withAnimation(AppAnimations.standard) {
                store.archiveAllTasks()
                selectedTasks.removeAll()
            }
        }
        PerformanceTelemetry.countEvent("archiveAllTasks.count", count: totalCount)
    }

    private func handleChatFilterSwipe(_ value: DragGesture.Value, listWidth: CGFloat) {
        guard !availableReactions.isEmpty else { return }
        guard !isContextMenuPresented else { return }

        // Не трогаем свайпы по правой части, где обычно начинаются свайпы по сообщениям.
        guard value.startLocation.x < listWidth * 0.45 else { return }

        let horizontal = value.translation.width
        let vertical = abs(value.translation.height)
        guard abs(horizontal) > 56, vertical < 48 else { return }

        let allItems = ["Все"] + availableReactions
        let currentIndex = selectedReaction.flatMap { allItems.firstIndex(of: $0) } ?? 0
        let nextIndex = horizontal < 0
            ? min(currentIndex + 1, allItems.count - 1)
            : max(currentIndex - 1, 0)

        guard nextIndex != currentIndex else { return }

        withAnimation(AppAnimations.quick) {
            isReactionSlideForward = horizontal < 0
            selectedReaction = nextIndex == 0 ? nil : allItems[nextIndex]
        }
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enableHaptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func scrollToBottomIfNeeded(using scrollProxy: ScrollViewProxy) {
        guard !didPerformInitialBottomScroll, let lastID = filteredTasks.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(AppAnimations.fade) {
                scrollProxy.scrollTo(lastID, anchor: .bottom)
            }
            didPerformInitialBottomScroll = true
        }
    }

}

private struct AppSettingsSheet: View {
    @ObservedObject var store: TaskStore
    @EnvironmentObject private var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings_enable_haptics") private var enableHaptics = true
    @AppStorage("settings_enable_rich_animations") private var enableRichAnimations = true
    @AppStorage("settings_compact_photos_layout") private var compactPhotosLayout = false
    @AppStorage(AppPreferenceKeys.themeMode) private var themeModeRawValue = AppThemeMode.system.rawValue
    @AppStorage(AppPreferenceKeys.accentColor) private var accentColorRawValue = AppAccentColor.blue.rawValue
    @AppStorage(AppPreferenceKeys.enableRecurrenceNotifications) private var enableRecurrenceNotifications = false
    @AppStorage(AppPreferenceKeys.recurrenceNotificationHour) private var recurrenceNotificationHour = 9
    @AppStorage(AppPreferenceKeys.recurrenceNotificationMinute) private var recurrenceNotificationMinute = 0
    @AppStorage(AppPreferenceKeys.chatBackgroundStyle) private var chatBackgroundStyleRawValue = ChatBackgroundStyle.system.rawValue
    @AppStorage(AppPreferenceKeys.chatBackgroundCustomImagePath) private var chatBackgroundCustomImagePath = ""
    @State private var showClearArchiveAlert = false
    @State private var showTestNotificationAlert = false
    @State private var testNotificationAlertMessage = ""
    @State private var selectedBackgroundImageItem: PhotosPickerItem?
    @State private var showPremiumErrorAlert = false
    @State private var showBackgroundImportErrorAlert = false
    @State private var backgroundImportErrorMessage = ""

    private var selectedAccentColor: AppAccentColor {
        AppAccentColor(rawValue: accentColorRawValue) ?? .blue
    }

    private var selectedChatBackgroundStyle: ChatBackgroundStyle {
        ChatBackgroundStyle(rawValue: chatBackgroundStyleRawValue) ?? .system
    }

    private var premiumFeatures: [(icon: String, title: String, subtitle: String)] {
        [
            ("sparkles.rectangle.stack.fill", "Анимированные фоны чата", "Яркие preset-фоны с живым переливом."),
            ("photo.on.rectangle.angled", "Свой фон из галереи", "Поставь любое фото как фон чата."),
            ("paintpalette.fill", "Премиум-визуал", "Единый стиль для тем и будущих улучшений.")
        ]
    }

    private var recurrenceTimeBinding: Binding<Date> {
        Binding {
            let calendar = Calendar.current
            return calendar.date(
                bySettingHour: recurrenceNotificationHour,
                minute: recurrenceNotificationMinute,
                second: 0,
                of: Date()
            ) ?? Date()
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            recurrenceNotificationHour = components.hour ?? 9
            recurrenceNotificationMinute = components.minute ?? 0
        }
    }

    @ViewBuilder
    private var premiumSection: some View {
        Section("Premium") {
            premiumHeroCard

            ForEach(Array(premiumFeatures.enumerated()), id: \.offset) { _, feature in
                HStack(spacing: 10) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(feature.subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: premiumManager.isPremiumUnlocked ? "checkmark.seal.fill" : "lock.fill")
                        .foregroundStyle(premiumManager.isPremiumUnlocked ? .green : .secondary)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.vertical, 2)
            }

            if !premiumManager.isPremiumUnlocked {
                Button {
                    Task {
                        await premiumManager.purchasePremium()
                    }
                } label: {
                    HStack {
                        if premiumManager.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Купить Premium")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(premiumManager.isProcessing)

                Button("Восстановить покупки") {
                    Task {
                        await premiumManager.restorePurchases()
                    }
                }
                .disabled(premiumManager.isProcessing)
            } else {
                Label("Спасибо за поддержку проекта", systemImage: "heart.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var interfaceSection: some View {
        Section("Интерфейс") {
            LabeledContent("Тема") {
                HStack(spacing: 8) {
                    ForEach(AppThemeMode.allCases, id: \.rawValue) { mode in
                        Button {
                            themeModeRawValue = mode.rawValue
                            applyThemeMode(mode)
                        } label: {
                            Image(systemName: mode.symbolName)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 30, height: 28)
                                .background(
                                    Capsule()
                                        .fill((AppThemeMode(rawValue: themeModeRawValue) ?? .system) == mode
                                              ? Color.secondary.opacity(0.24)
                                              : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Menu {
                ForEach(AppAccentColor.allCases, id: \.rawValue) { accent in
                    Button {
                        accentColorRawValue = accent.rawValue
                    } label: {
                        HStack(spacing: 8) {
                            Text(accent.title)
                            if selectedAccentColor == accent {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Цвет задач")
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(selectedAccentColor.color)
                            .font(.system(size: 8, weight: .bold))
                        Text(selectedAccentColor.title)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .tint(.primary)

            Toggle("Тактильный отклик", isOn: $enableHaptics)
            Toggle("Плавные анимации", isOn: $enableRichAnimations)
            Toggle("Компактная раскладка фото", isOn: $compactPhotosLayout)
        }
    }

    @ViewBuilder
    private var chatBackgroundSection: some View {
        Section("Фон чата") {
            if premiumManager.isPremiumUnlocked {
                Menu {
                    ForEach(ChatBackgroundStyle.allCases.filter { $0 != .custom }, id: \.rawValue) { style in
                        Button {
                            chatBackgroundStyleRawValue = style.rawValue
                        } label: {
                            HStack {
                                Text(style.title)
                                if selectedChatBackgroundStyle == style {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    LabeledContent("Пресет", value: selectedChatBackgroundStyle.title)
                }
                .tint(.primary)

                PhotosPicker(
                    selection: $selectedBackgroundImageItem,
                    matching: .images
                ) {
                    Label("Выбрать своё изображение", systemImage: "photo.on.rectangle")
                }
                .tint(.primary)

                if !chatBackgroundCustomImagePath.isEmpty {
                    Button("Сбросить свой фон", role: .destructive) {
                        ChatBackgroundStorage.removeImage(at: chatBackgroundCustomImagePath)
                        chatBackgroundCustomImagePath = ""
                        if selectedChatBackgroundStyle == .custom {
                            chatBackgroundStyleRawValue = ChatBackgroundStyle.goldenPeach.rawValue
                        }
                    }
                }
            } else {
                Label("Доступно в Premium", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section("Уведомления") {
            Toggle("Уведомлять о повторах", isOn: $enableRecurrenceNotifications)

            DatePicker(
                "Время уведомлений",
                selection: recurrenceTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .disabled(!enableRecurrenceNotifications)

            Button("Тестовое уведомление") {
                Task {
                    let ok = await RecurringTaskNotifications.sendTestNotification()
                    await MainActor.run {
                        testNotificationAlertMessage = ok
                            ? "Отправлено. Уведомление придет через пару секунд."
                            : "Нет доступа к уведомлениям. Разреши их в Настройках iOS."
                        showTestNotificationAlert = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dataSection: some View {
        Section("Данные") {
            LabeledContent("Активные задачи", value: "\(store.tasks.count)")
            LabeledContent("Архив", value: "\(store.archivedTasks.count)")

            Button("Сохранить сейчас") {
                store.flushPendingSaves()
            }

            Button("Очистить архив", role: .destructive) {
                showClearArchiveAlert = true
            }
            .disabled(store.archivedTasks.isEmpty)
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Аккаунт") {
            Text("Вход через Apple ID и iCloud-синхронизация временно отключены.")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private var developerSection: some View {
        #if DEBUG
        Section("Для разработчиков") {
            LabeledContent("Premium статус", value: premiumManager.isPremiumUnlocked ? "Активен" : "Не активен")

            Button("Активировать Premium") {
                premiumManager.unlockForDebug()
            }
            .disabled(premiumManager.isPremiumUnlocked)

            Button("Убрать Premium", role: .destructive) {
                premiumManager.removePremiumForDebug()
                chatBackgroundStyleRawValue = ChatBackgroundStyle.system.rawValue
            }
            .disabled(!premiumManager.isPremiumUnlocked)
        }
        #endif
    }

    private var premiumHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: premiumManager.isPremiumUnlocked ? "crown.fill" : "crown")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(premiumManager.isPremiumUnlocked ? .yellow : .white.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(premiumManager.isPremiumUnlocked ? Color.yellow.opacity(0.20) : Color.white.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(premiumManager.isPremiumUnlocked ? "Premium активен" : "Tasker Premium")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(premiumManager.isPremiumUnlocked
                         ? "Все премиум-функции уже доступны."
                         : "Прокачай визуал приложения и открой дополнительные возможности.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: premiumManager.isPremiumUnlocked
                    ? [Color(red: 0.15, green: 0.16, blue: 0.20), Color(red: 0.31, green: 0.24, blue: 0.10)]
                    : [Color(red: 0.14, green: 0.15, blue: 0.19), Color(red: 0.25, green: 0.15, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                premiumSection
                interfaceSection
                chatBackgroundSection
                notificationsSection
                dataSection
                accountSection
                developerSection
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .alert("Очистить архив?", isPresented: $showClearArchiveAlert) {
                Button("Очистить", role: .destructive) {
                    withAnimation {
                        store.archivedTasks.removeAll(keepingCapacity: true)
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это удалит все задачи из архива.")
            }
            .alert("Тест уведомлений", isPresented: $showTestNotificationAlert) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(testNotificationAlertMessage)
            }
            .alert("Premium", isPresented: $showPremiumErrorAlert) {
                Button("Ок", role: .cancel) {
                    premiumManager.lastErrorMessage = nil
                }
            } message: {
                Text(premiumManager.lastErrorMessage ?? "Не удалось выполнить операцию.")
            }
            .alert("Фон чата", isPresented: $showBackgroundImportErrorAlert) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(backgroundImportErrorMessage)
            }
        }
        .onAppear {
            applyThemeMode(AppThemeMode(rawValue: themeModeRawValue) ?? .system)
            store.refreshRecurringNotifications()
        }
        .onChange(of: enableRecurrenceNotifications) { _, _ in
            store.refreshRecurringNotifications()
        }
        .onChange(of: recurrenceNotificationHour) { _, _ in
            store.refreshRecurringNotifications()
        }
        .onChange(of: recurrenceNotificationMinute) { _, _ in
            store.refreshRecurringNotifications()
        }
        .onChange(of: selectedBackgroundImageItem) { _, item in
            guard premiumManager.isPremiumUnlocked, let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let savedPath = ChatBackgroundStorage.saveImageData(data, replacing: chatBackgroundCustomImagePath) {
                    await MainActor.run {
                        chatBackgroundCustomImagePath = savedPath
                        chatBackgroundStyleRawValue = ChatBackgroundStyle.custom.rawValue
                    }
                } else {
                    await MainActor.run {
                        backgroundImportErrorMessage = "Не удалось загрузить изображение. Попробуй выбрать другое фото."
                        showBackgroundImportErrorAlert = true
                    }
                }
                await MainActor.run {
                    selectedBackgroundImageItem = nil
                }
            }
        }
        .onChange(of: premiumManager.lastErrorMessage) { _, newValue in
            showPremiumErrorAlert = newValue != nil
        }
    }
}

struct TaskListView: View {
    let tasks: [TaskItem]
    let containerWidth: CGFloat
    let coordinateSpaceName: String
    let store: TaskStore
    @Binding var selectedPhotoForPreview: Data?
    @Binding var isPhotoPreviewPresented: Bool
    @Binding var isSelectionMode: Bool
    @Binding var selectedTasks: Set<UUID>
    var onContextMenuRequested: ((TaskItem) -> Void)? = nil

    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskBubbleView(
                    task: task,
                    containerWidth: containerWidth,
                    coordinateSpaceName: coordinateSpaceName,
                    store: store,
                    selectedPhotoForPreview: $selectedPhotoForPreview,
                    isPhotoPreviewPresented: $isPhotoPreviewPresented,
                    isSelectionMode: $isSelectionMode,
                    selectedTasks: $selectedTasks,
                    onContextMenuRequested: onContextMenuRequested
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
    let containerWidth: CGFloat
    let coordinateSpaceName: String
    let store: TaskStore
    @Binding var selectedPhotoForPreview: Data?
    @Binding var isPhotoPreviewPresented: Bool
    @Binding var isSelectionMode: Bool
    @Binding var selectedTasks: Set<UUID>
    var onContextMenuRequested: ((TaskItem) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppPreferenceKeys.accentColor) private var accentColorRawValue = AppAccentColor.blue.rawValue
    @AppStorage(AppPreferenceKeys.premiumUnlocked) private var isPremiumUnlocked = false
    @AppStorage(AppPreferenceKeys.chatBackgroundStyle) private var chatBackgroundStyleRawValue = ChatBackgroundStyle.system.rawValue

    private var appAccentColor: Color {
        (AppAccentColor(rawValue: accentColorRawValue) ?? .blue).color
    }

    private var effectiveChatBackgroundStyle: ChatBackgroundStyle {
        guard isPremiumUnlocked else { return .system }
        return ChatBackgroundStyle(rawValue: chatBackgroundStyleRawValue) ?? .system
    }

    private var bubbleFill: Color {
        if effectiveChatBackgroundStyle == .system {
            return selectedTasks.contains(task.id) ? appAccentColor.opacity(0.5) : appAccentColor
        }
        return selectedTasks.contains(task.id)
            ? Color.black.opacity(colorScheme == .dark ? 0.82 : 0.86)
            : Color.black.opacity(colorScheme == .dark ? 0.66 : 0.76)
    }

    private var bubbleSelectionStroke: Color {
        if effectiveChatBackgroundStyle == .system {
            return appAccentColor
        }
        return Color.white.opacity(colorScheme == .dark ? 0.26 : 0.20)
    }

    private var selectionAnimation: Animation {
        AppAnimations.quick
    }

    private var maxBubbleWidth: CGFloat {
        max(220, containerWidth * 0.75)
    }

    @ViewBuilder
    var body: some View {
        if onContextMenuRequested == nil {
            bubbleContent
                .contextMenu {
                    TaskContextMenu(
                        task: task,
                        store: store,
                        selectedTasks: $selectedTasks,
                        isSelectionMode: $isSelectionMode
                    )
                }
        } else {
            bubbleContent
                .highPriorityGesture(
                    LongPressGesture(minimumDuration: 0.30)
                        .onEnded { _ in
                            guard !isSelectionMode else { return }
                            onContextMenuRequested?(task)
                        }
                )
        }
    }

    private var bubbleContent: some View {
        HStack(alignment: .top) {
            // Чекбокс в режиме выбора
            if isSelectionMode {
                Button {
                    toggleSelection()
                } label: {
                    Image(systemName: selectedTasks.contains(task.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(appAccentColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                // Вложения
                if let photos = task.photos, !photos.isEmpty {
                    TaskPhotosLayout(photos: photos, onTap: handleTapOnPhoto)
                }

                // Текст задачи
                if !task.text.isEmpty {
                    HStack(spacing: 0) {
                        if task.recurrence != .none {
                            HStack(spacing: 4) {
                                Image(systemName: "repeat")
                                Text(task.recurrence.title)
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
                            )
                            .padding(.trailing, 6)
                        }

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
                                .background(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.18))
                                )
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 6)
                }

                HStack(spacing: 6) {
                    if task.isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.86))
                    }
                    Text(bubbleMetaText(for: task))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(bubbleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(bubbleSelectionStroke, lineWidth: 2)
                    .opacity(selectedTasks.contains(task.id) ? 1 : 0)
            )
            .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TaskBubbleFramePreferenceKey.self,
                        value: [task.id: proxy.frame(in: .named(coordinateSpaceName))]
                    )
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode { toggleSelection() }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isSelectionMode {
                Button {
                    withAnimation(AppAnimations.standard) {
                        store.archiveTask(task)
                    }
                } label: {
                    Label("Архив", systemImage: "archivebox.fill")
                }
                .tint(appAccentColor)
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
        withAnimation(selectionAnimation) {
            if selectedTasks.contains(task.id) {
                selectedTasks.remove(task.id)
            } else {
                selectedTasks.insert(task.id)
            }
        }
    }
}

struct ContextFocusedTaskBubble: View {
    let task: TaskItem
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppPreferenceKeys.accentColor) private var accentColorRawValue = AppAccentColor.blue.rawValue
    @AppStorage(AppPreferenceKeys.premiumUnlocked) private var isPremiumUnlocked = false
    @AppStorage(AppPreferenceKeys.chatBackgroundStyle) private var chatBackgroundStyleRawValue = ChatBackgroundStyle.system.rawValue

    private var appAccentColor: Color {
        (AppAccentColor(rawValue: accentColorRawValue) ?? .blue).color
    }

    private var effectiveChatBackgroundStyle: ChatBackgroundStyle {
        guard isPremiumUnlocked else { return .system }
        return ChatBackgroundStyle(rawValue: chatBackgroundStyleRawValue) ?? .system
    }

    private var bubbleFill: Color {
        if effectiveChatBackgroundStyle == .system {
            return appAccentColor
        }
        return Color.black.opacity(colorScheme == .dark ? 0.68 : 0.78)
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                if let photos = task.photos, !photos.isEmpty {
                    TaskPhotosLayout(photos: photos)
                }

                if !task.text.isEmpty {
                    HStack(spacing: 0) {
                        if task.recurrence != .none {
                            HStack(spacing: 4) {
                                Image(systemName: "repeat")
                                Text(task.recurrence.title)
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
                            )
                            .padding(.trailing, 6)
                        }
                        if task.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.trailing, 6)
                        }
                        Text(task.text)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                if !task.reactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(task.reactions, id: \.self) { reaction in
                            Text(reaction)
                                .font(.system(size: 13))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                }

                Text(bubbleMetaText(for: task))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18).fill(bubbleFill))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct TaskPhotosLayout: View {
    let photos: [Data]
    var onTap: ((Data) -> Void)? = nil
    @AppStorage("settings_compact_photos_layout") private var compactPhotosLayout = false

    private let gridSpacing: CGFloat = 8
    private let gridPhotoHeight: CGFloat = 80
    private let maxGridPhotos = 6

    private var singleWidth: CGFloat { compactPhotosLayout ? 188 : 220 }
    private var singleHeight: CGFloat { compactPhotosLayout ? 128 : 150 }
    private var pairWidth: CGFloat { compactPhotosLayout ? 120 : 140 }
    private var pairHeight: CGFloat { compactPhotosLayout ? 104 : 120 }
    private var tripleMainWidth: CGFloat { compactPhotosLayout ? 142 : 160 }
    private var tripleMainHeight: CGFloat { compactPhotosLayout ? 144 : 160 }
    private var tripleSideWidth: CGFloat { compactPhotosLayout ? 88 : 100 }
    private var tripleSideHeight: CGFloat { compactPhotosLayout ? 70 : 76 }

    private var gridRows: Int {
        let count = min(photos.count, maxGridPhotos)
        return Int(ceil(Double(count) / 2.0))
    }

    private var gridHeight: CGFloat {
        guard gridRows > 0 else { return 0 }
        return CGFloat(gridRows) * gridPhotoHeight + CGFloat(gridRows - 1) * gridSpacing
    }

    var body: some View {
        Group {
            switch photos.count {
            case 1:
                if let data = photos.first {
                    photoView(data, width: singleWidth, height: singleHeight, cornerRadius: 12)
                }
            case 2:
                HStack(spacing: 8) {
                    ForEach(Array(photos.prefix(2).enumerated()), id: \.offset) { _, data in
                        photoView(data, width: pairWidth, height: pairHeight, cornerRadius: 10)
                    }
                }
            case 3:
                HStack(spacing: 8) {
                    if let first = photos.first {
                        photoView(first, width: tripleMainWidth, height: tripleMainHeight, cornerRadius: 12)
                    }
                    VStack(spacing: 8) {
                        ForEach(Array(photos.dropFirst().prefix(2).enumerated()), id: \.offset) { _, data in
                            photoView(data, width: tripleSideWidth, height: tripleSideHeight, cornerRadius: 10)
                        }
                    }
                }
            default:
                GeometryReader { proxy in
                    let availableWidth = max(proxy.size.width, 0)
                    let cellWidth = max((availableWidth - gridSpacing) / 2, 0)
                    let columns = [
                        GridItem(.fixed(cellWidth), spacing: gridSpacing),
                        GridItem(.fixed(cellWidth), spacing: gridSpacing)
                    ]

                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(Array(photos.prefix(maxGridPhotos).enumerated()), id: \.offset) { _, data in
                            photoView(data, width: cellWidth, height: gridPhotoHeight, cornerRadius: 8)
                        }
                    }
                    .frame(width: availableWidth, alignment: .leading)
                }
                .frame(height: gridHeight)
            }
        }
    }

    private func photoView(
        _ data: Data,
        width: CGFloat?,
        height: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        let imageFrameShape = RoundedRectangle(cornerRadius: cornerRadius)

        return CachedDataImage(
            data: data,
            maxPixelSize: max(width ?? 0, height),
            content: { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: width == nil ? .infinity : nil)
                    .frame(width: width, height: height)
                    .clipped()
                    .clipShape(imageFrameShape)
                    .contentShape(imageFrameShape)
                    .onTapGesture {
                        onTap?(data)
                    }
            },
            placeholder: {
                imageFrameShape
                    .fill(Color.secondary.opacity(0.15))
                    .frame(maxWidth: width == nil ? .infinity : nil)
                    .frame(width: width, height: height)
            }
        )
    }
}

struct IMessageReactionsBar: View {
    static let visualHeight: CGFloat = 58.0

    let reactions: [String]
    let selectedReactions: Set<String>
    let allowsScroll: Bool
    let onTap: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Group {
            if allowsScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    reactionsRow
                }
            } else {
                reactionsRow
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.42), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.14), radius: 20, y: 8)
        .compositingGroup()
    }

    private var reactionsRow: some View {
                HStack(spacing: 18) {
                    ForEach(reactions, id: \.self) { emoji in
                        Button {
                            onTap(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 33))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            selectedReactions.contains(emoji)
                                                ? appAccentColor.opacity(colorScheme == .dark ? 0.34 : 0.22)
                                                : Color.clear
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
    }
}

struct IMessageActionsCard: View {
    static let baseHeight: CGFloat = 316.0
    private let rowHeight: CGFloat = 44.0
    private let contentVerticalPadding: CGFloat = 6.0
    private let sectionDividerVerticalPadding: CGFloat = 6.0

    let task: TaskItem
    let maxHeight: CGFloat
    let isScrollable: Bool
    let onReply: () -> Void
    let onCopy: () -> Void
    let onPinToggle: () -> Void
    let onRecurrenceChange: (TaskRecurrence) -> Void
    let onArchive: () -> Void
    let onSelect: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if isScrollable {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
            } else {
                content
            }
        }
        .frame(maxHeight: maxHeight)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.36), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.16), radius: 24, y: 10)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }

    private var content: some View {
        VStack(spacing: 0) {
            Text(exactTimestampText(task.date))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 6)

            row("Ответить", systemImage: "arrowshape.turn.up.left", rowHeight: rowHeight, action: onReply, hasDivider: false)
            row("Скопировать", systemImage: "doc.on.doc", rowHeight: rowHeight, action: onCopy, hasDivider: false)
            row(task.isPinned ? "Открепить" : "Закрепить", systemImage: "pin", rowHeight: rowHeight, action: onPinToggle, hasDivider: false)
            recurrenceMenuRow(rowHeight: rowHeight)
            row("Архивировать", systemImage: "archivebox", rowHeight: rowHeight, isDestructive: true, action: onArchive, hasDivider: false)

            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.12))
                .frame(height: 0.5)
                .padding(.horizontal, 28)
                .padding(.vertical, sectionDividerVerticalPadding)

            row("Выбрать", systemImage: "checkmark.circle", rowHeight: rowHeight, action: onSelect, hasDivider: false)
        }
        .padding(.vertical, contentVerticalPadding)
    }

    private func recurrenceMenuRow(rowHeight: CGFloat) -> some View {
        Menu {
            ForEach(TaskRecurrence.allCases, id: \.rawValue) { item in
                Button {
                    onRecurrenceChange(item)
                } label: {
                    HStack {
                        Text(item.title)
                        if task.recurrence == item {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "repeat")
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 26)
                Text("Повтор")
                    .font(.system(size: 17, weight: .regular))
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(task.recurrence.shortTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let nextText = recurrenceNextText {
                        Text(nextText)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                            .monospacedDigit()
                    }
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .frame(minHeight: rowHeight)
        }
        .buttonStyle(.plain)
    }

    private var recurrenceNextText: String? {
        guard task.recurrence != .none else { return nil }
        return MessageDateText.dayTimeFormatter.string(from: task.date)
    }

    private func row(
        _ title: String,
        systemImage: String,
        rowHeight: CGFloat = 56,
        isDestructive: Bool = false,
        action: @escaping () -> Void,
        hasDivider: Bool = true
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 16) {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 26)
                    Text(title)
                        .font(.system(size: 17, weight: .regular))
                    Spacer()
                }
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .padding(.horizontal, 20)
                .frame(height: rowHeight)
            }
            .buttonStyle(.plain)

            if hasDivider {
                Rectangle()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.12))
                    .frame(height: 0.5)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 4)
            }
        }
    }
}

private func bubbleTimestampText(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) {
        return MessageDateText.timeFormatter.string(from: date)
    }
    return MessageDateText.dayTimeFormatter.string(from: date)
}

private func bubbleMetaText(for task: TaskItem) -> String {
    if task.recurrence != .none, task.date > Date().addingTimeInterval(60) {
        return "Следующее: \(MessageDateText.dayTimeFormatter.string(from: task.date))"
    }
    return bubbleTimestampText(task.date)
}

private func exactTimestampText(_ date: Date) -> String {
    "Отправлено: \(MessageDateText.exactFormatter.string(from: date))"
}

private enum MessageDateText {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "dd.MM HH:mm"
        return formatter
    }()

    static let exactFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
