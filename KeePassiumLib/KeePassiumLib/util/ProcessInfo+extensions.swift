//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

extension ProcessInfo {
    
    public static var isRunningOnMac: Bool {
        return isiPadAppOnMac || isCatalystApp
    }
    
    private static var isiPadAppOnMac: Bool {
        #if compiler(>=5.3)
        guard #available(iOS 14, *) else {
            return false
        }
        return ProcessInfo.processInfo.isiOSAppOnMac
        #else
        return false
        #endif
    }
    
    private static var isCatalystApp: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }
}
