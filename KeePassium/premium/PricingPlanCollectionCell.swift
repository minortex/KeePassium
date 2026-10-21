//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class PricingPlanTitleCell: UITableViewCell {
    static let storyboardID = "TitleCell"

    @IBOutlet weak var highlightLabel: UILabel!
    @IBOutlet weak var highlightPanel: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var subpriceLabel: UILabel!
}

class PricingPlanConditionCell: UITableViewCell {
    static let storyboardID = "ConditionCell"

    @IBOutlet weak var checkmarkImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailButton: UIButton!
}

class PricingPlanBenefitCell: UITableViewCell {
    static let storyboardID = "BenefitCell"

    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
}

class PricingPlanCollectionCell: UICollectionViewCell {
    static let storyboardID = "PricingPlanCollectionCell"
}
