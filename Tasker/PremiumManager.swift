import Foundation
import Combine
import StoreKit

@MainActor
final class PremiumManager: ObservableObject {
    static let productID = "tasker.premium.chatbackground"

    @Published private(set) var isPremiumUnlocked: Bool
    @Published private(set) var isProcessing = false
    @Published var lastErrorMessage: String?

    init() {
        isPremiumUnlocked = UserDefaults.standard.bool(forKey: AppPreferenceKeys.premiumUnlocked)
        Task {
            await refreshEntitlements()
        }
    }

    func purchasePremium() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let products = try await Product.products(for: [Self.productID])
            guard let product = products.first else {
                lastErrorMessage = "Продукт Premium не найден. Добавь StoreKit configuration или продукт в App Store Connect."
                return
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    setPremiumUnlocked(true)
                case .unverified:
                    lastErrorMessage = "Покупка не прошла валидацию."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    func unlockForDebug() {
        setPremiumUnlocked(true)
    }

    func removePremiumForDebug() {
        setPremiumUnlocked(false)
    }
    #endif

    private func refreshEntitlements() async {
        var unlocked = UserDefaults.standard.bool(forKey: AppPreferenceKeys.premiumUnlocked)

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID {
                unlocked = true
                break
            }
        }

        setPremiumUnlocked(unlocked)
    }

    private func setPremiumUnlocked(_ value: Bool) {
        isPremiumUnlocked = value
        UserDefaults.standard.set(value, forKey: AppPreferenceKeys.premiumUnlocked)
    }
}
