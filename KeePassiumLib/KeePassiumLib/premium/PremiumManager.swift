//  KeePassium Password Manager
//  Copyright © 2018-2026 KeePassium Labs
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

public enum InAppProduct: String {
    case forever = "com.keepassium.ios.iap.forever"
}

public protocol PremiumManagerDelegate: class {
    func purchaseStarted(in premiumManager: PremiumManager)
    func purchaseSucceeded(_ product: InAppProduct, in premiumManager: PremiumManager)
    func purchaseDeferred(in premiumManager: PremiumManager)
    func purchaseFailed(with error: Error, in premiumManager: PremiumManager)
    func purchaseCancelledByUser(in premiumManager: PremiumManager)
    func purchaseRestoringFinished(in premiumManager: PremiumManager)
}

public final class PremiumManager {
    public static let shared = PremiumManager()

    public weak var delegate: PremiumManagerDelegate?

    public enum Status {
        case subscribed
    }

    public static let statusUpdateNotification =
        Notification.Name("com.keepassium.premiumManager.statusUpdated")

    public let status = Status.subscribed
    public let fallbackDate: Date? = Date.distantFuture
    public let isTrialAvailable = false

    private init() {
    }

    public func updateStatus() {
    }

    public func reloadReceipt() {
    }

    public func startObservingTransactions() {
    }

    public func finishObservingTransactions() {
    }

    public func requestAvailableProducts(
        completionHandler: @escaping (([AnyObject]?, Error?) -> Void)
    ) {
        completionHandler([], nil)
    }

    public func isPremiumSupportAvailable() -> Bool {
        return true
    }

    public func isAvailable(feature: PremiumFeature) -> Bool {
        return true
    }

    public func getPremiumProduct() -> InAppProduct? {
        return .forever
    }

    public func getPremiumExpiryDate() -> Date? {
        return .distantFuture
    }
}
