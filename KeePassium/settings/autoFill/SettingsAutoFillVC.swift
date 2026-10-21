//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class SettingsAutoFillVC: UITableViewController {

    @IBOutlet weak var copyTOTPSwitch: UISwitch!
    @IBOutlet weak var perfectMatchSwitch: UISwitch!
    @IBOutlet weak var appIconImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel()
        label.text = NSLocalizedString(
            "[Settings/AutoFill/ReadOnly] AutoFill is unavailable in this read-only iOS 9 version.",
            value: "AutoFill is unavailable in this read-only iOS 9 version.",
            comment: "Message shown in the AutoFill settings retained for storyboard compatibility")
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .auxiliaryText
        tableView.tableFooterView = label
    }
}
