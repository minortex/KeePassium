//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryFieldEditorCoordinatorDelegate: AnyObject {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator)
}

final class EntryFieldEditorCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: EntryFieldEditorCoordinatorDelegate?

    init(router: NavigationRouter, database: Database, parent: Group, target: Entry?) {
    }

    func start() {
        dismissHandler?(self)
    }
}
