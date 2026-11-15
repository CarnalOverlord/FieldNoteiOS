import Foundation
import Combine
import StoreKit

@MainActor
final class BillingManager: ObservableObject {
    // Keep these in sync with the App Store Connect subscription products.
    static let monthlyProductID = "FN_MNTH"
    static let yearlyProductID = "FN_ANN"
    static let productIDs: Set<String> = [monthlyProductID, yearlyProductID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var activeProductIDs: Set<String> = []
    @Published private(set) var premiumEntitlement: PremiumEntitlement?
    @Published private(set) var isLoading = false
    @Published var message: String?
    var onEntitlementUpdated: ((PremiumEntitlement) -> Void)?
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await observeTransactions() }
        Task { await refresh() }
    }

    deinit { updatesTask?.cancel() }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Self.productIDs).sorted { lhs, rhs in
                if lhs.id == rhs.id { return false }
                if lhs.id == Self.monthlyProductID { return true }
                if rhs.id == Self.monthlyProductID { return false }
                return lhs.id < rhs.id
            }
        } catch {
            message = "Subscriptions are temporarily unavailable. Please try again later."
        }
        do { apply(try await APIClient.shared.billingEntitlement()) }
        catch { message = error.localizedDescription }
    }

    func purchase(_ product: Product) async {
        message = nil
        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction = try verified(result)
                let entitlement = try await APIClient.shared.verifyApplePurchase(signedTransaction: result.jwsRepresentation)
                await transaction.finish()
                apply(entitlement)
                message = entitlement.is_premium ? "Subscription verified and active." : "The App Store purchase was received, but no active subscription was found. Refresh subscriptions to try again."
            case .pending:
                message = "Purchase is awaiting approval."
            case .userCancelled:
                break
            @unknown default:
                message = "The purchase could not be completed."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        message = nil
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements {
                guard let transaction = try? verified(result),
                      Self.productIDs.contains(transaction.productID),
                      transaction.revocationDate == nil else { continue }
                let entitlement = try await APIClient.shared.verifyApplePurchase(signedTransaction: result.jwsRepresentation)
                apply(entitlement)
            }
            let entitlement = try await APIClient.shared.billingEntitlement()
            apply(entitlement)
            message = entitlement.is_premium ? "Subscription restored and verified." : "No active subscription was found."
        } catch {
            message = error.localizedDescription
        }
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? verified(result), Self.productIDs.contains(transaction.productID) else { continue }
            do {
                let entitlement = try await APIClient.shared.verifyApplePurchase(signedTransaction: result.jwsRepresentation)
                await transaction.finish()
                apply(entitlement)
                message = entitlement.is_premium ? "Subscription verified and active." : "No active subscription was found."
            } catch { message = error.localizedDescription }
        }
    }

    private func apply(_ entitlement: PremiumEntitlement) {
        premiumEntitlement = entitlement
        if entitlement.is_premium, let plan = entitlement.plan {
            switch plan {
            case "monthly": activeProductIDs = [Self.monthlyProductID]
            case "yearly": activeProductIDs = [Self.yearlyProductID]
            default: activeProductIDs = []
            }
        } else {
            activeProductIDs = []
        }
        onEntitlementUpdated?(entitlement)
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw BillingError.unverified
        }
    }
}

private enum BillingError: Error { case unverified }
