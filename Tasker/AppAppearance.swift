import SwiftUI
import UIKit

enum AppPreferenceKeys {
    static let themeMode = "settings_theme_mode"
    static let accentColor = "settings_accent_color"
    static let enableRecurrenceNotifications = "settings_enable_recurrence_notifications"
    static let recurrenceNotificationHour = "settings_recurrence_notification_hour"
    static let recurrenceNotificationMinute = "settings_recurrence_notification_minute"
    static let premiumUnlocked = "settings_premium_unlocked"
    static let chatBackgroundStyle = "settings_chat_background_style"
    static let chatBackgroundCustomImagePath = "settings_chat_background_custom_image_path"
}

enum AppThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system:
            return "Авто"
        case .light:
            return "Светлая"
        case .dark:
            return "Тёмная"
        }
    }

    var symbolName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppAccentColor: String, CaseIterable {
    case blue
    case green
    case orange
    case pink
    case red
    case indigo

    var title: String {
        switch self {
        case .blue:
            return "Синий"
        case .green:
            return "Зелёный"
        case .orange:
            return "Оранжевый"
        case .pink:
            return "Розовый"
        case .red:
            return "Красный"
        case .indigo:
            return "Индиго"
        }
    }

    var color: Color {
        switch self {
        case .blue:
            return .blue
        case .green:
            return .green
        case .orange:
            return .orange
        case .pink:
            return .pink
        case .red:
            return .red
        case .indigo:
            return .indigo
        }
    }
}

enum ChatBackgroundStyle: String, CaseIterable {
    case system
    case goldenPeach
    case sunsetCandy
    case mintSky
    case custom

    var title: String {
        switch self {
        case .system:
            return "Системный"
        case .goldenPeach:
            return "Золотой персик"
        case .sunsetCandy:
            return "Закатный candy"
        case .mintSky:
            return "Мятное небо"
        case .custom:
            return "Свой фон"
        }
    }
}

private struct AppAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .blue
}

extension EnvironmentValues {
    var appAccentColor: Color {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }
}

@MainActor
func applyThemeMode(_ mode: AppThemeMode) {
    let style: UIUserInterfaceStyle
    switch mode {
    case .system:
        style = .unspecified
    case .light:
        style = .light
    case .dark:
        style = .dark
    }

    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .forEach { $0.overrideUserInterfaceStyle = style }
}
