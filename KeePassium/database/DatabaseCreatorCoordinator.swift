//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol DatabaseCreatorCoordinatorDelegate: class {
    func didCreateDatabase(
        in databaseCreatorCoordinator: DatabaseCreatorCoordinator,
        database urlRef: URLReference)
}

class DatabaseCreatorCoordinator: NSObject, Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    weak var delegate: DatabaseCreatorCoordinatorDelegate?

    private let router: NavigationRouter
    private let databaseCreatorVC: DatabaseCreatorVC
    
    init(router: NavigationRouter) {
        self.router = router
        databaseCreatorVC = DatabaseCreatorVC.create()
        super.init()

        databaseCreatorVC.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        databaseCreatorVC.disableForReadOnlyMode()
        router.push(databaseCreatorVC, animated: true, onPop: { [weak self] _ in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
}

extension DatabaseCreatorCoordinator: DatabaseCreatorDelegate {
    func didPressCancel(in databaseCreatorVC: DatabaseCreatorVC) {
        router.pop(viewController: databaseCreatorVC, animated: true)
    }
    
    func didPressContinue(in databaseCreatorVC: DatabaseCreatorVC) {
        databaseCreatorVC.showReadOnlyMessage()
    }
    
    func didPressErrorDetails(in databaseCreatorVC: DatabaseCreatorVC) {
    }
    
    func didPressPickKeyFile(in databaseCreatorVC: DatabaseCreatorVC, at popoverAnchor: PopoverAnchor) {
        databaseCreatorVC.showReadOnlyMessage()
    }
    
}
