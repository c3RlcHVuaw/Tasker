import SwiftUI

@main
struct TaskerApp: App {
    @State private var isLoading = true
    private let splashDelay: TimeInterval = 0.8
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    LoadingView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(nil)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + splashDelay) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoading = false
                    }
                }
            }
        }
    }
}

