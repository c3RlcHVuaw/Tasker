import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AppleAccountManager: ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var displayName: String?
    @Published private(set) var email: String?
    @Published private(set) var credentialState: ASAuthorizationAppleIDProvider.CredentialState = .notFound
    @Published private(set) var isSignedIn = false
    @Published var lastError: String?

    var avatarText: String {
        let source = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let source, !source.isEmpty {
            let parts = source.split(separator: " ").prefix(2)
            let initials = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
            if !initials.isEmpty { return initials }
        }

        if let email, let first = email.first {
            return String(first).uppercased()
        }
        return "👤"
    }

    private let userIDKey = "apple_user_id"
    private let displayNameKey = "apple_display_name"
    private let emailKey = "apple_email"

    private let provider = ASAuthorizationAppleIDProvider()

    init() {
        userID = UserDefaults.standard.string(forKey: userIDKey)
        displayName = UserDefaults.standard.string(forKey: displayNameKey)
        email = UserDefaults.standard.string(forKey: emailKey)

        Task {
            await refreshCredentialState()
        }
        refreshDerivedState()
    }

    func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                lastError = "Не удалось получить Apple ID credential."
                return
            }
            userID = credential.user

            if let fullName = credential.fullName {
                let formatter = PersonNameComponentsFormatter()
                let formatted = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
                if !formatted.isEmpty {
                    displayName = formatted
                }
            }
            if let newEmail = credential.email, !newEmail.isEmpty {
                email = newEmail
            }

            persistSession()
            credentialState = .authorized
            lastError = nil
            refreshDerivedState()

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            lastError = humanReadable(error: error)
            refreshDerivedState()
        }
    }

    func signOut() {
        userID = nil
        displayName = nil
        email = nil
        credentialState = .notFound
        lastError = nil
        clearPersistedSession()
        refreshDerivedState()
    }

    func refreshCredentialState() async {
        guard let userID else {
            credentialState = .notFound
            return
        }

        do {
            let state = try await credentialState(for: userID)
            credentialState = state
            if state != .authorized {
                signOut()
            }
            refreshDerivedState()
        } catch {
            credentialState = .notFound
            lastError = error.localizedDescription
            refreshDerivedState()
        }
    }

    private func credentialState(for userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }

    private func persistSession() {
        UserDefaults.standard.set(userID, forKey: userIDKey)
        UserDefaults.standard.set(displayName, forKey: displayNameKey)
        UserDefaults.standard.set(email, forKey: emailKey)
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: displayNameKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
    }

    private func refreshDerivedState() {
        isSignedIn = (userID != nil && credentialState == .authorized)
    }

    private func humanReadable(error: Error) -> String {
        guard let authError = error as? ASAuthorizationError else {
            return error.localizedDescription
        }

        switch authError.code {
        case .unknown:
            return "Не удалось выполнить вход. Проверьте, что в Xcode включены Sign in with Apple и iCloud/CloudKit для этого Bundle ID."
        case .notHandled:
            return "Запрос входа не был обработан. Попробуйте еще раз."
        case .failed:
            return "Вход через Apple ID не выполнен. Попробуйте еще раз."
        case .invalidResponse:
            return "Получен некорректный ответ от Apple ID."
        case .notInteractive:
            return "Невозможно показать окно входа в текущем режиме."
        case .matchedExcludedCredential:
            return "Данные Apple ID недоступны для этого входа."
        case .credentialImport:
            return "Ошибка импорта данных учетной записи Apple ID."
        case .credentialExport:
            return "Ошибка экспорта данных учетной записи Apple ID."
        case .canceled:
            return ""
        @unknown default:
            return error.localizedDescription
        }
    }
}
