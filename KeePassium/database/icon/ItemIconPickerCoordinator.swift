//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol ItemIconPickerCoordinatorDelegate: class {
    func didSelectIcon(standardIcon: IconID, in coordinator: ItemIconPickerCoordinator)
    func didSelectIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator)
    func didDeleteIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator)
}

class ItemIconPickerCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: ItemIconPickerCoordinatorDelegate?
    weak var item: DatabaseItem?

    init(router: NavigationRouter, database: Database) {
    }

    func start() {
        dismissHandler?(self)
    }
}
