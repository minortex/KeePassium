//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

struct ContextualAction {
    public enum Style {
        case `default`
        case destructive
        case cancel
    }
    
    var title: String
    var imageName: SystemImageName?
    var style: Style
    var color: UIColor?
    var handler: (() -> Void)
    
    var image: UIImage? {
        guard let imageName = imageName else {
            return nil
        }
        return UIImage.get(imageName)
    }

    public func toAlertAction() -> UIAlertAction {
        let alertActionStyle: UIAlertAction.Style
        switch style {
        case .default:
            alertActionStyle = .default
        case .destructive:
            alertActionStyle = .destructive
        case .cancel:
            alertActionStyle = .cancel
        }
        
        return UIAlertAction(
            title: title,
            style: alertActionStyle,
            handler: { action in
                self.handler()
            }
        )
    }
    
}
