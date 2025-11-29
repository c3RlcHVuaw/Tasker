import SwiftUI
import Combine

enum Tabs: Hashable {
    case home, archive, search
}

struct ContentView: View {
    @StateObject private var store = TaskStore()
    @State private var searchText = ""
    @State private var selectedTab: Tabs = .home

    var body: some View {
        if #available(iOS 18.0, *) {
            // ✅ Новый API Tab для iOS 18
            TabView(selection: $selectedTab) {
                Tab(value: Tabs.home) {
                    HomeView(store: store)
                } label: {
                    Label("Главная", systemImage: "house.fill")
                }

                Tab(value: Tabs.archive) {
                    ArchiveView(store: store)
                } label: {
                    Label("Архив", systemImage: "archivebox.fill")
                }

                // ✅ Нативный поисковый таб справа
                Tab(value: Tabs.search, role: .search) {
                    SearchResults(store: store, searchText: $searchText)
                }
            }
            .tint(.blue)
            .modifier(KeyboardResponsive())
        } else {
            // 🔙 Fallback для iOS 17 и ниже
            TabView(selection: $selectedTab) {
                HomeView(store: store)
                    .tabItem { Label("Главная", systemImage: "house.fill") }
                    .tag(Tabs.home)

                ArchiveView(store: store)
                    .tabItem { Label("Архив", systemImage: "archivebox.fill") }
                    .tag(Tabs.archive)

                SearchResults(store: store, searchText: $searchText)
                    .tabItem { Label("Поиск", systemImage: "magnifyingglass") }
                    .tag(Tabs.search)
            }
            .tint(.blue)
        }
    }
}


// ✅ Модификатор, который сдвигает контент при появлении клавиатуры
struct KeyboardResponsive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            .onReceive(Publishers.keyboardHeightPublisher) { height in
                keyboardHeight = height
            }
    }
}

//// ✅ Паблишер, отслеживающий высоту клавиатуры
extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height
            }

        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        return Publishers.Merge(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

#Preview {
    ContentView()
}
