//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public class Clipboard {

    public static let general = Clipboard()
    
    private var insertedText: String?
    private var insertedURL: URL?
    
    private init() {
    }
    
    public func insert(url: URL, timeout: Double?=nil) {
        Diag.debug("Inserted a URL to clipboard")
        UIPasteboard.general.url = url
        insertedURL = url
    }
    
    public func insert(text: String, timeout: Double?=nil) {
        Diag.debug("Inserted a string to clipboard")
        UIPasteboard.general.string = text
        insertedText = text
    }
    
    public func clear() {
        let pasteboard = UIPasteboard.general

        var containsOurStuff = false
        if let insertedText = insertedText {
            containsOurStuff = containsOurStuff || (pasteboard.string == insertedText)
        }
        if let insertedURL = insertedURL {
            containsOurStuff = containsOurStuff || (pasteboard.url == insertedURL)
        }
        
        if containsOurStuff {
            pasteboard.string = ""
            self.insertedText = nil
            self.insertedURL = nil
            Diag.info("Clipboard content cleared")
        }
    }
}
