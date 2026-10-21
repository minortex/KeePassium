//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIColor {
    private static func named(_ name: String) -> UIColor? {
        if #available(iOS 11, *) {
            return UIColor(named: name)
        } else {
            return nil
        }
    }
    
    static var actionTint: UIColor {
        return named("ActionTint") ?? UIColor.kpBlue
    }
    static var actionText: UIColor {
        return named("ActionText") ?? .white
    }
    static var iconTint: UIColor {
        return named("iconTint") ?? UIColor.kpBlue
    }
    static var destructiveTint: UIColor {
        return named("DestructiveTint") ?? UIColor.kpRed
    }
    static var destructiveText: UIColor {
        return named("DestructiveText") ?? .white
    }
    static var highlightTint: UIColor {
        return named("HighlightTint") ?? UIColor.kpRed
    }
    static var highglightText: UIColor {
        return named("HighlightText") ?? .white
    }
    static var errorMessage: UIColor {
        return UIColor.kpRed
    }
    static var primaryText: UIColor {
        return named("PrimaryText") ?? .black
    }
    static var auxiliaryText: UIColor {
        return named("AuxiliaryText") ?? .darkGray
    }
    static var disabledText: UIColor {
        return named("DisabledText") ?? .darkGray
    }
    static var passwordLetters: UIColor {
        return primaryText
    }
    static var passwordDigits: UIColor {
        return named("PasswordDigits") ?? UIColor.kpBlue
    }
    static var passwordSymbols: UIColor {
        return named("PasswordSymbols") ?? UIColor.kpRed
    }


    
    static let mfiKeyActionSheetIdleColor: UIColor = .white
    
    static let mfiKeyActionSheetTouchColor =
        UIColor(red: 186/255, green: 233/255, blue: 80/255, alpha: 1)
    
    static let mfiKeyActionSheetProcessingColor =
        UIColor(red: 118/255, green: 214/255, blue: 255/255, alpha: 1)

    
    static let kpRed = UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1)
    static let kpOrange = UIColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1)
    static let kpYellow = UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 1)
    static let kpGreen = UIColor(red: 76/255, green: 217/255, blue: 100/255, alpha: 1)
    static let kpTealBlue = UIColor(red: 90/255, green: 200/255, blue: 250/255, alpha: 1)
    static let kpBlue = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)
    static let kpPurple = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1)
    static let kpPink = UIColor(red: 255/255, green: 45/255, blue: 85/255, alpha: 1)
}
