import SwiftUI
import Combine

struct SearchResultsView: View {
    @ObservedObject var store: TaskStore
    @Environment(\.colorScheme) private var colorScheme

    // Provided by parent (ContentView)
    @Binding var queryText: String
    @Binding var rawSearchText: String
    @Binding var filterWithPhoto: Bool
    @Binding var filterArchive: Bool
    @Binding var selectedReaction: String?
    @Binding var selectedPhotoForPreview: Data?
    @State private var contextMenuTask: TaskItem?
    @Binding var isContextMenuPresented: Bool
    @State private var isContextMenuContentVisible = false
    @State private var contextMenuPresentationID = UUID()
    @State private var contextMenuAnimationTask: Task<Void, Never>?
    @State private var bubbleFrames: [UUID: CGRect] = [:]

    private enum SearchContentState: Equatable {
        case emptyQuery
        case noMatches
        case results
    }

    private var contentState: SearchContentState {
        if filteredTasks.isEmpty && !rawSearchText.isEmpty { return .noMatches }
        if filteredTasks.isEmpty { return .emptyQuery }
        return .results
    }

    private var stateAnimation: Animation {
        if #available(iOS 26.0, *) {
            return .smooth(duration: 0.22)
        } else {
            return .easeInOut(duration: 0.22)
        }
    }

    private var mutationAnimation: Animation {
        if #available(iOS 26.0, *) {
            return .snappy(duration: 0.26, extraBounce: 0.08)
        } else {
            return .spring(response: 0.30, dampingFraction: 0.84)
        }
    }

    var filteredTasks: [TaskItem] {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)

        var tasks: [TaskItem] = filterArchive ? store.archivedTasks : store.tasks

        if filterWithPhoto {
            tasks = tasks.filter { $0.photos != nil && !($0.photos?.isEmpty ?? true) }
        }

        if !query.isEmpty {
            tasks = tasks.filter { $0.text.localizedCaseInsensitiveContains(query) }
        }

        if let reaction = selectedReaction {
            tasks = tasks.filter { $0.reactions.contains(reaction) }
        }

        return tasks
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                VStack {
                    VStack(spacing: 0) {
                        // Список результатов поиска
                        Group {
                            if filteredTasks.isEmpty && !rawSearchText.isEmpty {
                                ContentUnavailableView(
                                    "Ничего не найдено",
                                    systemImage: "magnifyingglass",
                                    description: Text("Попробуйте другой поисковый запрос")
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else if filteredTasks.isEmpty {
                                ContentUnavailableView(
                                    "Поиск задач",
                                    systemImage: "magnifyingglass",
                                    description: Text("Введите текст для поиска")
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else {
                                GeometryReader { listProxy in
                                    List(filteredTasks) { task in
                                        TaskBubbleView(
                                            task: task,
                                            containerWidth: listProxy.size.width,
                                            coordinateSpaceName: "searchSpace",
                                            store: store,
                                            selectedPhotoForPreview: $selectedPhotoForPreview,
                                            isPhotoPreviewPresented: .constant(false),
                                            isSelectionMode: .constant(false),
                                            selectedTasks: .constant(Set<UUID>()),
                                            onContextMenuRequested: openMessageContextMenu
                                        )
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                    }
                                    .listStyle(.plain)
                                    .scrollContentBackground(.hidden)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .contentTransition(.opacity)
                        .animation(stateAnimation, value: contentState)

                        Spacer()
                    }
                    .background(Color.clear)
                }
                .blur(radius: isContextMenuPresented ? 10 : 0)
                .saturation(isContextMenuPresented ? 0.18 : 1)
                .brightness(isContextMenuPresented ? -0.04 : 0)
                .allowsHitTesting(!isContextMenuPresented)

                if let task = contextMenuTask {
                    messageContextOverlay(
                        for: task,
                        isOverlayPresented: isContextMenuPresented,
                        isContentPresented: isContextMenuContentVisible
                    )
                }
            }
            .coordinateSpace(name: "searchSpace")
            .onPreferenceChange(TaskBubbleFramePreferenceKey.self) { bubbleFrames = $0 }
            .onDisappear {
                contextMenuAnimationTask?.cancel()
            }
        }
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
                    .overlay(Color.black.opacity(colorScheme == .dark ? 0.26 : 0.14))
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
                    onArchive: {
                        if let current = store.tasks.first(where: { $0.id == task.id }) {
                            withAnimation(mutationAnimation) {
                                store.archiveTask(current)
                            }
                        }
                        closeMessageContextMenu()
                    },
                    onSelect: { closeMessageContextMenu() }
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        contextMenuAnimationTask?.cancel()
        contextMenuPresentationID = UUID()
        isContextMenuPresented = false
        isContextMenuContentVisible = false
        if let updated = store.tasks.first(where: { $0.id == task.id }) {
            contextMenuTask = updated
        } else if let updatedArchived = store.archivedTasks.first(where: { $0.id == task.id }) {
            contextMenuTask = updatedArchived
        } else {
            contextMenuTask = task
        }
        withAnimation(.easeOut(duration: 0.16)) {
            isContextMenuPresented = true
        }
        let openID = contextMenuPresentationID
        contextMenuAnimationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled, openID == contextMenuPresentationID else { return }
            withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86, blendDuration: 0.14)) {
                isContextMenuContentVisible = true
            }
        }
    }

    private func closeMessageContextMenu() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        contextMenuAnimationTask?.cancel()
        let closingID = contextMenuPresentationID
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.98, blendDuration: 0.08)) {
            isContextMenuContentVisible = false
        }
        contextMenuAnimationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 70_000_000)
            guard !Task.isCancelled, closingID == contextMenuPresentationID else { return }
            withAnimation(.easeIn(duration: 0.14)) {
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
}

struct SearchScreen: View {
    @ObservedObject var store: TaskStore

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isSearching) private var isSearching

    @State private var searchText: String = ""
    @State private var filterWithPhoto: Bool = false
    @State private var filterArchive: Bool = false

    @State private var selectedReaction: String? = nil
    @State private var selectedPhotoForPreview: Data? = nil
    @State private var selectedPhotoItem: SearchPhotoItem?
    @State private var didConfigureSearchAppearance = false
    @State private var debouncedSearchText: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var keyboardHeight: CGFloat = 0
    @State private var isContextMenuPresented = false

    private var reactionSourceTasks: [TaskItem] {
        let query = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var tasks = filterArchive ? store.archivedTasks : store.tasks

        if filterWithPhoto {
            tasks = tasks.filter { $0.photos != nil && !($0.photos?.isEmpty ?? true) }
        }

        if !query.isEmpty {
            tasks = tasks.filter { $0.text.localizedCaseInsensitiveContains(query) }
        }

        return tasks
    }

    private var availableReactions: [String] {
        usedReactions(from: reactionSourceTasks)
    }

    private var reactionChipsBottomPadding: CGFloat {
        // Keep chips attached above the bottom search field when search UI is active.
        if keyboardHeight > 0 {
            return isSearching ? 64 : 18
        }
        return isSearching ? 56 : 10
    }

    var body: some View {
        NavigationStack {
            SearchResultsView(
                store: store,
                queryText: $debouncedSearchText,
                rawSearchText: $searchText,
                filterWithPhoto: $filterWithPhoto,
                filterArchive: $filterArchive,
                selectedReaction: $selectedReaction,
                selectedPhotoForPreview: $selectedPhotoForPreview,
                isContextMenuPresented: $isContextMenuPresented
            )
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbar(isContextMenuPresented ? .hidden : .visible, for: .tabBar)
            .toolbar(isContextMenuPresented ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SearchFiltersMenuButton(
                        filterWithPhoto: $filterWithPhoto,
                        filterArchive: $filterArchive
                    )
                }
            }
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color.clear, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
        }
        // убираем белую подложку у области поиска (nav bar + search field)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.clear, for: .navigationBar)

        // tab bar тоже делаем прозрачным
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.clear, for: .tabBar)
        .toolbarBackground(.hidden, for: .tabBar)

        .searchable(text: $searchText, prompt: Text("Введите запрос"))
        .overlay(alignment: .bottom) {
            if !availableReactions.isEmpty && !isContextMenuPresented {
                SearchReactionChipsBar(
                    reactions: availableReactions,
                    selectedReaction: $selectedReaction
                )
                .padding(.horizontal, 12)
                .padding(.bottom, reactionChipsBottomPadding)
                .zIndex(10)
            }
        }
        .background(screenBackground)
        .onAppear {
            guard !didConfigureSearchAppearance else { return }
            didConfigureSearchAppearance = true
            configureSearchBarAppearance()
            debouncedSearchText = searchText
        }
        .onDisappear {
            searchDebounceTask?.cancel()
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                debouncedSearchText = newValue
            }
        }
        .onChange(of: selectedPhotoForPreview) { _, newValue in
            if let data = newValue {
                selectedPhotoItem = SearchPhotoItem(data: data)
            }
        }
        .onReceive(Publishers.keyboardHeightPublisher) { height in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardHeight = height
            }
        }
        .onChange(of: availableReactions) { _, newValue in
            if let selectedReaction, !newValue.contains(selectedReaction) {
                self.selectedReaction = nil
            }
        }
        .sheet(item: $selectedPhotoItem, onDismiss: {
            selectedPhotoForPreview = nil
        }) { item in
            QuickLookPreview(data: item.data) {
                selectedPhotoItem = nil
                selectedPhotoForPreview = nil
            }
        }
        // REMOVED forced light appearance for adaptive theme
    }

    private var screenBackground: some View {
        ZStack {
            // База — системный фон (адаптируется под светлую/тёмную тему)
            Color(.systemBackground)
                .ignoresSafeArea()

            // Низ — лёгкое затемнение (в тёмной теме чуть сильнее)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.20 : 0.05),
                    Color.clear
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func configureSearchBarAppearance() {
        let searchBar = UISearchBar.appearance()
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.setSearchFieldBackgroundImage(UIImage(), for: .normal)
        searchBar.barTintColor = .clear
        searchBar.isTranslucent = true
        if #available(iOS 13.0, *) {
            // Убираем фоновую подложку под нижним поисковым инпутом.
            searchBar.searchTextField.backgroundColor = .clear
            searchBar.searchTextField.textColor = UIColor.label
        }
        let textField = UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self])
        textField.backgroundColor = .clear
        textField.borderStyle = .none
    }
}

fileprivate struct SearchPhotoItem: Identifiable {
    let id = UUID()
    let data: Data
}


#Preview {
    SearchScreen(store: TaskStore())
}
