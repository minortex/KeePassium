//  KeePassium Password Manager
//  Copyright © 2018-2026 KeePassium Labs
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

public enum WebDAVFileURL {
    public static let schemePrefix = "webdav"
    public static let schemes = ["http", "https"]

    public static func build(nakedURL: URL) -> URL {
        return nakedURL.withSchemePrefix(schemePrefix)
    }

    public static func canonicalize(_ url: URL) -> URL {
        let isRemote = url.isRemoteURL
        let nakedURL = isRemote ? url.withoutSchemePrefix() : url
        guard var components = URLComponents(url: nakedURL, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        if components.scheme == "http" && components.port == 80 {
            components.port = nil
        } else if components.scheme == "https" && components.port == 443 {
            components.port = nil
        }
        components.user = nil
        components.password = nil
        guard let canonicalURL = components.url else {
            return url
        }
        return isRemote ? build(nakedURL: canonicalURL) : canonicalURL
    }

    internal static func getNakedURL(from prefixedURL: URL) -> URL {
        return prefixedURL.isRemoteURL
            ? prefixedURL.withoutSchemePrefix()
            : prefixedURL
    }
}
