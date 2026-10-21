//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public extension Settings {
    
    var premiumDatabaseLockTimeout: Settings.DatabaseLockTimeout {
        return databaseLockTimeout
    }
    
    var premiumIsBiometricAppLockEnabled: Bool {
        return isBiometricAppLockEnabled
    }
    
    var premiumIsKeepKeyFileAssociations: Bool {
        return isKeepKeyFileAssociations
    }
    
    var premiumIsLockDatabasesOnTimeout: Bool {
        let actualValue = Settings.current.isLockDatabasesOnTimeout
        return actualValue
    }
    
    func isAvailable(timeout: Settings.DatabaseLockTimeout, for status: PremiumManager.Status) -> Bool {
        return true
    }
    
    func isShownAvailable(timeout: Settings.DatabaseLockTimeout, for status: PremiumManager.Status) -> Bool {
        return true
    }
}
