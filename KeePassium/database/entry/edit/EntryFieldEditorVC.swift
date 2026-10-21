//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol EntryFieldEditorDelegate: class {
    func didPressCancel(in viewController: EntryFieldEditorVC)
}

final class EntryFieldEditorVC: UITableViewController, Refreshable {
    @IBOutlet weak var doneButton: UIBarButtonItem!

    var fields = [EditableField]()
    weak var delegate: EntryFieldEditorDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        doneButton.isEnabled = false
        addReadOnlyNotice()
    }

    func refresh() {
        tableView.reloadData()
    }

    private func addReadOnlyNotice() {
        let label = UILabel()
        label.text = NSLocalizedString(
            "[Entry/Edit/ReadOnly] Editing entries is unavailable in this read-only version.",
            value: "Editing entries is unavailable in this read-only version.",
            comment: "Message shown in the entry editor retained for storyboard compatibility")
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .auxiliaryText
        tableView.tableFooterView = label
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }

    @IBAction func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
}
