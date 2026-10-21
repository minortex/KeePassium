//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

public class PremiumUpgradeHelper {
    init() {
    }

    public func performActionOrOfferUpgrade(
        _ feature: PremiumFeature,
        in viewController: UIViewController,
        actionHandler: @escaping () -> Void
    ) {
        actionHandler()
    }

    public func offerUpgrade(_ feature: PremiumFeature, in viewController: UIViewController) {
    }
}
