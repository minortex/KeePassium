//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

internal let urlSchemePrefixSeparator: Character = "+"

public extension URL {
    var schemePrefix: String? {
        guard let scheme = self.scheme else { return nil }
        let schemeParts = scheme.split(separator: urlSchemePrefixSeparator)
        guard schemeParts.count > 1 else { return nil }
        return String(schemeParts[0])
    }

    var schemeWithoutPrefix: String? {
        guard let scheme = self.scheme else { return nil }
        return String(scheme.split(
            separator: urlSchemePrefixSeparator,
            maxSplits: 1
        ).last ?? "")
    }

    func withSchemePrefix(_ prefix: String) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        let mainScheme = schemeWithoutPrefix ?? ""
        components.scheme = prefix + String(urlSchemePrefixSeparator) + mainScheme
        return components.url ?? self
    }

    func withoutSchemePrefix() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.scheme = schemeWithoutPrefix
        return components.url ?? self
    }

    var isRemoteURL: Bool {
        return schemePrefix == WebDAVFileURL.schemePrefix
    }
}

public extension URL {
    
    var domain2: String? {
        guard let names = host?.split(separator: ".") else { return nil }
        let nameCount = names.count
        if nameCount >= 2 {
            return String(names[nameCount - 2])
        }
        return nil
    }
    
    var isDirectory: Bool {
        let res = try? resourceValues(forKeys: [.isDirectoryKey])
        return res?.isDirectory ?? false
    }
    
    var isExcludedFromBackup: Bool? {
        let res = try? resourceValues(forKeys: [.isExcludedFromBackupKey])
        return res?.isExcludedFromBackup
    }
    
    var isInTrashDirectory: Bool {
        do {
            let fileManager = FileManager.default
            var relationship = FileManager.URLRelationship.other
            try fileManager.getRelationship(&relationship, of: .trashDirectory, in: [], toItemAt: self)
            return relationship == .contains
        } catch {
            let isSimpleNameMatch = self.pathComponents.contains(".Trash")
            return isSimpleNameMatch
        }
    }
    
    @discardableResult
    mutating func setExcludedFromBackup(_ isExcluded: Bool) -> Bool {
        var values = URLResourceValues()
        values.isExcludedFromBackup = isExcluded
        do {
            try setResourceValues(values)
            if isExcludedFromBackup != nil && isExcludedFromBackup! == isExcluded {
                return true
            }
            Diag.warning("Failed to change backup attribute: the modification did not last.")
            return false
        } catch {
            Diag.warning("Failed to change backup attribute [reason: \(error.localizedDescription)]")
            return false
        }
    }
    
    var redacted: URL {
        let isDirectory = self.isDirectory
        return self.deletingLastPathComponent().appendingPathComponent("_redacted_", isDirectory: isDirectory)
    }
}
