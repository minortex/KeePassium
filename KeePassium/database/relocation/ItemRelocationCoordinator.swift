//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

public enum ItemRelocationMode {
    case move
    case copy
}

protocol ItemRelocationCoordinatorDelegate: class {
    func didRelocateItems(in coordinator: ItemRelocationCoordinator)
}

class ItemRelocationCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: ItemRelocationCoordinatorDelegate?

    init(
        router: NavigationRouter,
        database: Database,
        mode: ItemRelocationMode,
        itemsToRelocate: [Weak<DatabaseItem>]
    ) {
    }

    func start() {
        dismissHandler?(self)
    }
}
