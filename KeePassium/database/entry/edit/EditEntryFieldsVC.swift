//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

protocol EditEntryFieldsDelegate: class {
    func entryEditor(entryDidChange entry: Entry)
}

class EditEntryTitleCell: UITableViewCell {
    public static let storyboardID = "TitleCell"

    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleTextField: ValidatingTextField!
    @IBOutlet weak var changeIconButton: UIButton!
}

class EditEntryVC: UITableViewController, Refreshable {
    private static let storyboardID = "EditEntryFieldsVC"
    @IBOutlet weak var addFieldButton: UIBarButtonItem!

    private weak var entry: Entry?
    private weak var delegate: EditEntryFieldsDelegate?

    public enum Mode {
        case create
        case edit
    }

    private var mode: Mode = .edit

    static func make(
        parent group: Group,
        popoverSource: UIView?,
        delegate: EditEntryFieldsDelegate?
    ) -> UIViewController {
        make(mode: .create, entry: nil, popoverSource: popoverSource, delegate: delegate)
    }

    static func make(
        mode: Mode,
        entry: Entry?,
        popoverSource: UIView?,
        delegate: EditEntryFieldsDelegate?
    ) -> UIViewController {
        let editEntryVC = AppStoryboard.entry.instance.instantiateViewController(
            withIdentifier: EditEntryVC.storyboardID) as! EditEntryVC
        editEntryVC.mode = .edit
        editEntryVC.entry = entry
        editEntryVC.delegate = delegate

        let navVC = ProgressNavigationController(rootViewController: editEntryVC)
        navVC.modalPresentationStyle = .formSheet
        if let popover = navVC.popoverPresentationController, let popoverSource = popoverSource {
            popover.sourceView = popoverSource
            popover.sourceRect = popoverSource.bounds
        }
        return navVC
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addFieldButton.isEnabled = false
        navigationItem.rightBarButtonItem = nil

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

    func refresh() {
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }

    @IBAction func onCancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func onSaveAction(_ sender: Any) {
        let alert = UIAlertController.make(
            title: LString.titleError,
            message: NSLocalizedString(
                "[Entry/Edit/ReadOnly] Editing entries is unavailable in this read-only version.",
                value: "Editing entries is unavailable in this read-only version.",
                comment: "Message shown in the entry editor retained for storyboard compatibility"),
            dismissButtonTitle: LString.actionOK)
        present(alert, animated: true, completion: nil)
    }

    @IBAction func didPressAddField(_ sender: Any) {
        onSaveAction(sender)
    }
}
