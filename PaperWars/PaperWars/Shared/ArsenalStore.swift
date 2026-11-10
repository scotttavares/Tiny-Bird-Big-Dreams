import Foundation
import Observation
import StoreKit

/// The one in-app purchase: "Full Arsenal" (non-consumable, Family Sharing on), which unlocks the General, the terrain
/// maps, the Reinforcements and Fort must fall options, 5 more soldier voices, every pen, the Full Arsenal medal and the
/// One-Man Army badge. StoreKit is the source of truth; the page only shows what this reports.
@MainActor
@Observable
final class ArsenalStore {
    static let productID = "com.tinybirdbigdreams.paperwars.fullarsenal"

    private(set) var owned = false
    private(set) var price: String?
    /// Called whenever `owned` or `price` changes, and with a message when a purchase doesn't go through.
    var onChange: ((_ owned: Bool, _ price: String?) -> Void)?
    var onFailure: ((_ message: String) -> Void)?

    private var product: Product?
    private var updates: Task<Void, Never>?

    init() {
        // Purchases made elsewhere (another device, Family Sharing, Ask to Buy approval, refunds) arrive here.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self.refresh()
            }
        }
    }

    /// Loads the price and checks whether the player (or their family) owns the Full Arsenal.
    func refresh() async {
        if product == nil {
            product = try? await Product.products(for: [Self.productID]).first
        }
        var isOwned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID, transaction.revocationDate == nil {
                isOwned = true
            }
        }
        update(owned: isOwned, price: product?.displayPrice)
    }

    func buy() async {
        if product == nil { await refresh() }
        guard let product else {
            onFailure?("The App Store isn't reachable right now. Try again in a moment.")
            return
        }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                update(owned: true, price: product.displayPrice)
            case .success(.unverified):
                onFailure?("Apple couldn't verify that purchase.")
            case .pending:
                onFailure?("Waiting for approval. It unlocks as soon as it's approved.")
            case .userCancelled:
                onFailure?("")
            @unknown default:
                onFailure?("The purchase didn't go through.")
            }
        } catch {
            onFailure?("The purchase didn't go through.")
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            onFailure?("Couldn't reach the App Store to restore.")
        }
        await refresh()
        if !owned { onFailure?("No Full Arsenal purchase found on this Apple ID.") }
    }

    private func update(owned: Bool, price: String?) {
        self.owned = owned
        self.price = price
        onChange?(owned, price)
    }
}
