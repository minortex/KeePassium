//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIFont {
    public static func systemFont(
        ofSize size: CGFloat = 17,
        forTextStyle style: UIFont.TextStyle,
        weight: UIFont.Weight = .regular)
        -> UIFont
    {
        var font: UIFont
        if UIAccessibility.isBoldTextEnabled {
            font = UIFont.boldSystemFont(ofSize: size)
        } else {
            if #available(iOS 8.2, *) {
                font = UIFont.systemFont(ofSize: size, weight: weight)
            } else {
                font = UIFont.systemFont(ofSize: size)
            }
        }
        if #available(iOS 11, *) {
            return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        } else {
            return font.withSize(size * UIFont.preferredFont(forTextStyle: style).pointSize / 17)
        }
    }
    
    public static func monospaceFont(
        ofSize size: CGFloat = 17,
        forTextStyle style: UIFont.TextStyle)
        -> UIFont
    {
        var font: UIFont
        #if compiler(>=5.1)
        if #available(iOS 13, *) {
            let weight: Weight = UIAccessibility.isBoldTextEnabled ? .bold : .regular
            font = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        } else
        #endif
        if UIAccessibility.isBoldTextEnabled {
            font = UIFont(name: "Menlo-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
        } else {
            font = UIFont(name: "Menlo", size: size) ?? UIFont.systemFont(ofSize: size)
        }
        if #available(iOS 11, *) {
            return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        } else {
            return font.withSize(size * UIFont.preferredFont(forTextStyle: style).pointSize / 17)
        }
    }
}
