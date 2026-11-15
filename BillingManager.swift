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
    @Published private(set) var isLoading = false
    @Published var message: String?
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
            products = try await Product.products(for: Self.productIDs).sorted {
                $0.id == Self.monthlyProductID
            }
            await updateEntitlements()
        } catch {
            message = "Subscriptions are temporarily unavailable. Please try again later."
        }
    }

    func purchase(_ product: Product) async {
        message = nil
        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction = try verified(result)
                await transaction.finish()
                await updateEntitlements()
                message = "Subscription active."
                // Backend receipt/transaction synchronization will be added when its endpoint is ready.
            case .pending:
                message = "Purchase is awaiting approval."
            case .userCancelled:
                break
            @unknown default:
                message = "The purchase could not be completed."
            }
        } catch {
            message = "The purchase could not be completed. Please try again."
        }
    }

    func restore() async {
        message = nil
        do {
            try await AppStore.sync()
            await updateEntitlements()
            message = activeProductIDs.isEmpty ? "No active subscription was found." : "Purchases restored."
        } catch {
            message = "Purchases could not be restored. Please try again."
        }
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? verified(result) else { continue }
            await transaction.finish()
            await updateEntitlements()
        }
    }

    private func updateEntitlements() async {
        var active = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            active.insert(transaction.productID)
        }
        activeProductIDs = active
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw BillingError.unverified
        }
    }
}

private enum BillingError: Error { case unverified }
