//  KeePassium Password Manager
//  Copyright © 2018-2026 KeePassium Labs
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

extension Date {
    private static let httpHeaderFormats = [
        "EEE, dd MMM yyyy HH:mm:ss z",
        "EEEE, dd-MMM-yy HH:mm:ss z",
        "EEE MMM d HH:mm:ss yyyy",
    ]

    public static func parse(httpHeaderValue: String?) -> Date? {
        guard let dateString = httpHeaderValue else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in Date.httpHeaderFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}
