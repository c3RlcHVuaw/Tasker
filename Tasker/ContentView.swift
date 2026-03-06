import SwiftUI

enum AppTab: Hashable {
    case home, archive, search
}

struct ContentView: View {
    @StateObject private var store = TaskStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home

    @State private var selectedPhotoForPreview: Data?
    @State private var isPhotoPreviewPresented = false
    @State private var selectedPhotoItem: PhotoItem?
    @State private var didPrepareTabBarAppearance = false

    var body: some View {
        content
            .tabViewStyle(.automatic)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color.clear, for: .tabBar)
            .scrollContentBackground(.hidden)
            .onAppear {
                guard !didPrepareTabBarAppearance else { return }
                didPrepareTabBarAppearance = true
                prepareTabBarAppearance()
            }
            .onChange(of: selectedPhotoForPreview) { _, newValue in
                handlePhotoSelection(newValue)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    store.flushPendingSaves()
                }
            }
            .sheet(item: $selectedPhotoItem, onDismiss: {
                selectedPhotoForPreview = nil
            }, content: photoPreviewSheet)
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 26.0, *) {
            tabsIOS26
        } else {
            tabsFallback
        }
    }

    // MARK: - Tabs

    private var tabsIOS26: some View {
        TabView {
            Tab("Главная", systemImage: "house") {
                homeTab
            }

            Tab("Архив", systemImage: "archivebox") {
                archiveTab
            }

            Tab(role: .search) {
                searchTab
            }
        }
    }

    private var tabsFallback: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tabItem { Label("Главная", systemImage: "house") }
                .tag(AppTab.home)

            archiveTab
                .tabItem { Label("Архив", systemImage: "archivebox") }
                .tag(AppTab.archive)

            searchTab
                .tabItem { Label("Поиск", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
        }
        .animation(AppAnimations.tabSwitch, value: selectedTab)
    }

    // MARK: - Tab contents

    private var homeTab: some View {
        HomeView(
            store: store,
            selectedPhotoForPreview: $selectedPhotoForPreview,
            isPhotoPreviewPresented: $isPhotoPreviewPresented
        )
    }

    private var archiveTab: some View {
        ArchiveView(
            store: store,
            selectedPhotoForPreview: $selectedPhotoForPreview,
            isPhotoPreviewPresented: $isPhotoPreviewPresented
        )
    }

    private var searchTab: some View {
        SearchScreen(store: store)
    }

    // MARK: - Appearance & Sheets

    private func prepareTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        appearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        UITabBar.appearance().isTranslucent = true
    }

    private func handlePhotoSelection(_ newValue: Data?) {
        if let data = newValue {
            selectedPhotoItem = PhotoItem(data: data)
        }
    }

    private func photoPreviewSheet(item: PhotoItem) -> some View {
        QuickLookPreview(data: item.data) {
            selectedPhotoItem = nil
            selectedPhotoForPreview = nil
        }
    }
}

fileprivate struct PhotoItem: Identifiable {
    let id = UUID()
    let data: Data
}

#Preview {
    ContentView()
        .environmentObject(PremiumManager())
}
