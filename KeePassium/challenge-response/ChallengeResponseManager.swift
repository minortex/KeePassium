//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class ChallengeResponseManager {
    static let instance = ChallengeResponseManager()
    
    public private(set) var supportsNFC = false
    public private(set) var supportsMFI = false
    
    private init() {
    }
    
    public static func makeHandler(for yubiKey: YubiKey?) -> ChallengeHandler? {
        return nil
    }
}
