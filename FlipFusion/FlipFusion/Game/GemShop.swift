import Foundation
import Observation
import StoreKit

/// Sells packs of gems through the App Store. Apple takes the payment; this class
/// asks for the packs, starts a purchase, and hands the gems to the game once
/// Apple confirms a purchase is genuine.
@MainActor
@Observable
final class GemShop {
    /// A pack on sale. Its price is set in App Store Connect, not here.
    struct Pack: Identifiable, Equatable, Sendable {
        let id: String
        let gems: Int
    }

    static let packs: [Pack] = [
        Pack(id: "com.tinybirdbigdreams.flipfusion.gems.small", gems: 25),
        Pack(id: "com.tinybirdbigdreams.flipfusion.gems.medium", gems: 60),
        Pack(id: "com.tinybirdbigdreams.flipfusion.gems.large", gems: 150),
    ]

    static func pack(for productID: String) -> Pack? {
        packs.first { $0.id == productID }
    }

    /// The packs as the App Store describes them, cheapest first. Empty until loaded.
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    /// True when the App Store was asked for the packs and gave none.
    private(set) var isUnavailable = false
    /// True while a purchase sheet is up.
    private(set) var isBuying = false
    /// A line to show under the packs after a purchase attempt.
    private(set) var notice: String?

    @ObservationIgnored private let store: GameStore
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(store: GameStore) {
        self.store = store
        // The unit tests launch the app with no App Store to talk to.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        // Purchases that finish outside the app (a parent approving one, or one that
        // was cut off) arrive here.
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.deliver(result)
            }
        }
        Task { [weak self] in
            await self?.load()
        }
    }

    /// Asks the App Store for the packs. Safe to call again after a failure.
    func load() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let found = try await Product.products(for: Self.packs.map(\.id))
            products = found.sorted { $0.price < $1.price }
            isUnavailable = products.isEmpty
        } catch {
            isUnavailable = true
        }
    }

    func buy(_ product: Product) async {
        guard !isBuying else { return }
        isBuying = true
        defer { isBuying = false }
        notice = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await deliver(verification)
            case .pending:
                notice = "Waiting for approval. Your gems arrive as soon as the purchase is approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            notice = "The purchase did not go through. Please try again."
        }
    }

    /// Gives the gems for a purchase Apple has verified, then tells Apple it is done.
    private func deliver(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.revocationDate == nil, let pack = Self.pack(for: transaction.productID) {
            let count = pack.gems * max(1, transaction.purchasedQuantity)
            if store.addPurchasedGems(count, purchaseID: String(transaction.id)) {
                notice = "\(count) gems added. Thank you!"
            }
        }
        await transaction.finish()
    }
}
