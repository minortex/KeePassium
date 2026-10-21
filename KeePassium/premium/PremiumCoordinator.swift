//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class PremiumCoordinator: NSObject, Coordinator {
    public static let desiredModalPresentationStyle = UIModalPresentationStyle.pageSheet

    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    init(router: NavigationRouter) {
    }

    func start() {
        dismissHandler?(self)
    }
}
