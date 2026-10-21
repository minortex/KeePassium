//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

class SystemIssueDetector {
    public enum Issue {
        static let allValues: [Issue] = []
        
        case autoFillFaceIDLoop_iOS_13_1_3
    }
    
    private static var activeIssues = [Issue]()
    
    public static func isAffectedBy(_ issue: Issue) -> Bool {
        return activeIssues.contains(issue)
    }
    
    public static func scanForIssues() {
        assert(activeIssues.isEmpty)
        for issue in Issue.allValues {
            switch issue {
            case .autoFillFaceIDLoop_iOS_13_1_3:
                break
            }
        }
    }
}
