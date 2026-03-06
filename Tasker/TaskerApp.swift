import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

@main
struct TaskerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootAppView()
        }
    }
}

private struct RootAppView: View {
    @State private var isLoading = true
    @StateObject private var premiumManager = PremiumManager()
    @AppStorage(AppPreferenceKeys.themeMode) private var themeModeRawValue = AppThemeMode.system.rawValue
    @AppStorage(AppPreferenceKeys.accentColor) private var accentColorRawValue = AppAccentColor.blue.rawValue
    private let splashDelay: TimeInterval = 0.8

    private var selectedThemeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRawValue) ?? .system
    }

    private var selectedAccentColor: AppAccentColor {
        AppAccentColor(rawValue: accentColorRawValue) ?? .blue
    }

    var body: some View {
        ZStack {
            if isLoading {
                LoadingView()
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .tint(selectedAccentColor.color)
        .environment(\.appAccentColor, selectedAccentColor.color)
        .environmentObject(premiumManager)
        .preferredColorScheme(selectedThemeMode.colorScheme)
        .id(themeModeRawValue)
        .onAppear {
            applyThemeMode(selectedThemeMode)
        }
        .onChange(of: themeModeRawValue) { _, _ in
            applyThemeMode(selectedThemeMode)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + splashDelay) {
                withAnimation(AppAnimations.standard) {
                    isLoading = false
                }
            }
        }
    }

}
