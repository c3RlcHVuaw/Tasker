import SwiftUI
import Combine

enum AppTab: Hashable {
    case home, search, archive
}

struct ContentView: View {
    @StateObject private var store = TaskStore()
    @State private var selectedTab: AppTab = .home

    @State private var selectedPhotoForPreview: Data?
    @State private var isPhotoPreviewPresented = false
    @State private var selectedPhotoItem: PhotoItem?
    @State private var searchText: String = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            // Главная
            SwiftUI.Tab("Главная", systemImage: "house", value: AppTab.home) {
                HomeView(
                    store: store,
                    selectedPhotoForPreview: $selectedPhotoForPreview,
                    isPhotoPreviewPresented: $isPhotoPreviewPresented
                )
            }

            // Поиск
            SwiftUI.Tab("Поиск", systemImage: "magnifyingglass",
                        value: AppTab.search, role: .search) {
                SearchView(
                    store: store,
                    selectedPhotoForPreview: $selectedPhotoForPreview,
                    isPhotoPreviewPresented: $isPhotoPreviewPresented,
                    searchText: $searchText
                )
                .searchable(text: $searchText, prompt: "Введите запрос")
            }

            // Архив
            SwiftUI.Tab("Архив", systemImage: "archivebox", value: AppTab.archive) {
                ArchiveView(
                    store: store,
                    selectedPhotoForPreview: $selectedPhotoForPreview,
                    isPhotoPreviewPresented: $isPhotoPreviewPresented
                )
            }
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .scrollContentBackground(.hidden)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = .clear
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            UITabBar.appearance().isTranslucent = true
            UITabBar.appearance().backgroundColor = .clear
            UITabBar.appearance().backgroundImage = UIImage()
            UITabBar.appearance().shadowImage = UIImage()
        }
        .onChange(of: selectedPhotoForPreview) { newValue in
            if let data = newValue {
                selectedPhotoItem = PhotoItem(data: data)
            }
        }
        .sheet(item: $selectedPhotoItem) { item in
            QuickLookPreview(data: item.data) {
                selectedPhotoItem = nil
                selectedPhotoForPreview = nil
            }
        }
    }
}

fileprivate struct PhotoItem: Identifiable {
    let id = UUID()
    let data: Data
}



#Preview {
    ContentView()
}
