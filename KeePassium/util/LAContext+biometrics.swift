//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import LocalAuthentication
import UIKit

enum KPBiometryType {
    case touchID
    case none
}

extension LAContext {
    public static func getBiometryType() -> KPBiometryType {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        let isAvailable = context.canEvaluatePolicy(policy, error: nil)
        return isAvailable ? .touchID : .none
    }
}

extension KPBiometryType {
    var name: String? {
        switch self {
        case .touchID:
            return NSLocalizedString(
                "[BiometricAuthType] Touch ID",
                value: "Touch ID",
                comment: "Name of biometric authentication method. Trademarked, do not translate unless Apple traslated it to your language.")
        case .none:
            return nil
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .touchID:
            return UIImage(asset: .biometryTouchIDListitem)
        case .none:
            return nil
        }
    }
}
