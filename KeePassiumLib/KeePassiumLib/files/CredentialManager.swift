//  KeePassium Password Manager
//  Copyright © 2018-2026 KeePassium Labs
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

public final class NetworkCredential: Codable {
    public let username: String
    public let password: String
    public let allowUntrustedCertificate: Bool

    public init(username: String, password: String, allowUntrustedCertificate: Bool) {
        self.username = username
        self.password = password
        self.allowUntrustedCertificate = allowUntrustedCertificate
    }

    internal func serialize() -> Data {
        return try! JSONEncoder().encode(self)
    }

    internal static func deserialize(from data: Data) -> NetworkCredential? {
        return try? JSONDecoder().decode(NetworkCredential.self, from: data)
    }

    internal func toURLCredential() -> URLCredential {
        return URLCredential(
            user: username,
            password: password,
            persistence: .forSession
        )
    }
}

public final class CredentialManager {
    public static let shared = CredentialManager()

    private init() {
    }

    public func get(for url: URL) -> NetworkCredential? {
        do {
            return try Keychain.shared.getNetworkCredential(for: canonicalURL(url))
        } catch {
            Diag.error("Failed to get network credential [message: \(error.localizedDescription)]")
            return nil
        }
    }

    public func store(credential: NetworkCredential, for url: URL) {
        do {
            try Keychain.shared.store(networkCredential: credential, for: canonicalURL(url))
        } catch {
            Diag.error("Failed to store network credential [message: \(error.localizedDescription)]")
        }
    }

    public func remove(for url: URL) {
        do {
            try Keychain.shared.removeNetworkCredential(for: canonicalURL(url))
        } catch {
            Diag.error("Failed to remove network credential [message: \(error.localizedDescription)]")
        }
    }

    public func removeAll() {
        do {
            try Keychain.shared.removeAllNetworkCredentials()
        } catch {
            Diag.error("Failed to remove network credentials [message: \(error.localizedDescription)]")
        }
    }

    private func canonicalURL(_ url: URL) -> URL {
        return WebDAVFileURL.getNakedURL(
            from: WebDAVFileURL.canonicalize(url)
        )
    }
}
