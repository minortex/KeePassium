//  KeePassium Password Manager
//  Copyright © 2018–2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class URLOpener: NSObject {
    
    private weak var application: UIApplication?
    
    internal init(_ responder: UIResponder?) {
        super.init()
        
        var responder = responder
        while responder != nil {
            if let application = responder as? UIApplication {
                self.application = application
                break
            }
            responder = responder?.next
        }
    }
    
    internal init(_ application: UIApplication) {
        super.init()
        self.application = application
    }

    public func open(
        url: URL,
        completionHandler: ((Bool)->Void)?=nil
    ) {
        application?.kp_open(url, completionHandler: completionHandler)
    }

        
    func canOpenURL(_ url: URL) -> Bool {
        let result = application?.canOpenURL(url)
        return result ?? false
    }
    
}

extension UIApplication {
    func kp_open(
        _ url: URL,
        completionHandler: ((Bool) -> Void)? = nil
    ) {
        if #available(iOS 10, *) {
            open(url, options: [:], completionHandler: completionHandler)
        } else {
            completionHandler?(openURL(url))
        }
    }
}
