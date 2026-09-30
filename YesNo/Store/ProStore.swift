import Foundation
import Observation
import StoreKit

/// The one optional, one-time purchase ("Pro"), built on StoreKit 2.
///
/// Rules this type exists to keep:
/// - Ownership is read from StoreKit's signed, on-device transactions, so Pro works offline.
/// - Restore Purchases always works and always says what happened.
/// - No receipts, account data or purchase details are sent anywhere by the app.
@MainActor
@Observable
final class ProStore {
    enum ProductState: Equatable {
        case notLoaded
        case loading
        case loaded
        /// The App Store couldn't be reached, or the product isn't set up yet.
        case unavailable
    }

    static let fallbackProductID = "com.tomnorush.yesno.pro"

    /// True in the "Offline" build configuration (the `OFFLINE` compilation flag): a personal build
    /// for testing on your own device. Every Pro feature is unlocked and StoreKit is never used,
    /// so it needs no App Store Connect setup and makes no network requests at all.
    static let isOfflineBuild: Bool = {
        #if OFFLINE
        return true
        #else
        return false
        #endif
    }()

    /// Read from Info.plist (`YesNoProProductID`, derived from the bundle ID in Config/Shared.xcconfig).
    static var productID: String {
        (Bundle.main.object(forInfoDictionaryKey: "YesNoProProductID") as? String)
            .flatMap { $0.isEmpty ? nil : $0 } ?? fallbackProductID
    }

    private static let cacheKey = "pro.unlocked.cache"

    private(set) var isPro: Bool
    private(set) var product: Product?
    private(set) var productState: ProductState = .notLoaded
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    /// A short, human message after purchase or restore ("Pro restored", "Nothing to restore", …).
    var statusMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    /// Lives as long as the store, which lives as long as the app.
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if Self.isOfflineBuild {
            isPro = true
            return
        }
        // Cached so Pro themes and odds are right on the first frame; StoreKit confirms right after.
        isPro = defaults.bool(forKey: Self.cacheKey)
        updatesTask = Task { [weak self] in
            // Purchases finished elsewhere: Ask to Buy approvals, other devices, refunds.
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refreshEntitlements() }
    }

    // MARK: - Product

    func loadProductIfNeeded() async {
        guard !Self.isOfflineBuild, product == nil, productState != .loading else { return }
        productState = .loading
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            productState = product == nil ? .unavailable : .loaded
        } catch {
            productState = .unavailable
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard !Self.isOfflineBuild, let product, !isPurchasing else { return }
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                if isPro {
                    statusMessage = String(localized: "Pro unlocked. Thank you!")
                }
            case .pending:
                statusMessage = String(localized: "Your purchase is waiting for approval. Pro will unlock as soon as it's approved.")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            statusMessage = String(localized: "The purchase didn't go through. You haven't been charged.")
        }
    }

    // MARK: - Restore

    /// Asks the App Store to sync, then re-reads what this Apple Account owns.
    func restore() async {
        guard !Self.isOfflineBuild, !isRestoring else { return }
        isRestoring = true
        statusMessage = nil
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            // Still check local entitlements below; they may already be there.
        }
        await refreshEntitlements()
        statusMessage = isPro
            ? String(localized: "Pro restored. Thanks for your support!")
            : String(localized: "No previous purchase was found for this Apple Account.")
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        guard !Self.isOfflineBuild else { return }
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        setPro(owned)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            // Unverified transactions are ignored; they never unlock anything.
            return
        }
        if transaction.productID == Self.productID {
            setPro(transaction.revocationDate == nil)
        }
        await transaction.finish()
    }

    private func setPro(_ value: Bool) {
        guard isPro != value else { return }
        isPro = value
        defaults.set(value, forKey: Self.cacheKey)
    }
}
