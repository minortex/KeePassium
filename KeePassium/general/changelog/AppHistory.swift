//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

struct AppHistory: Decodable {
    struct Section: Decodable {
        let version: String
        let releaseDate: Date
        let items: [Item]
    }
    
    struct Item: Decodable {
        let title: String
        let type: ItemType
    }
    
    enum ItemType: Int, Codable {
        case none = 0
        case free = 1
        case premium = 2
    }
    
    let sections: [Section]
}

extension AppHistory {

    public static func load(from fileName: String) -> AppHistory? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "") else {
            Diag.error("Failed to find app history file")
            return nil
        }
        do {
            let fileContents = try Data(contentsOf: url)
            let jsonDecoder = JSONDecoder()
            #if compiler(>=5.1)
            jsonDecoder.dateDecodingStrategy = .iso8601
            #else
            jsonDecoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                guard let date = formatter.date(from: value) else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Invalid ISO 8601 date")
                }
                return date
            }
            #endif
            let appHistory = try jsonDecoder.decode(AppHistory.self, from: fileContents)
            return appHistory
        } catch {
            Diag.error("Failed to load app history file [reason: \(error.localizedDescription)]")
            return nil
        }
    }
}
