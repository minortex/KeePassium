//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class PricingPlanPickerVC: UIViewController {
    public static func create() -> PricingPlanPickerVC {
        return PricingPlanPickerVC.instantiateFromStoryboard()
    }
}
