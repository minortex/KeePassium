//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public extension Date {
    static var now: Date { return Date() }
    
    private static let iso8601DateFormatters = [
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
    ].map { format -> DateFormatter in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
    
    private static let miniKeePassDateFormatter = { () -> DateFormatter in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static internal let secondsBetweenSwiftAndDotNetReferenceDates = Int64(63113904000)

    init?(iso8601string string: String?) {
        guard let string = string else { return nil }
        if let date = Date.iso8601DateFormatters
            .compactMap({ $0.date(from: string) })
            .first {
            self = date
            return
        }
        guard let date = Date.miniKeePassDateFormatter.date(from: string) else {
            return nil
        }
        self = date
    }
    
    init?(base64Encoded string: String?) {
        guard let data = ByteArray(base64Encoded: string) else { return nil }
        guard let secondsSinceDotNetReferenceDate = Int64(data: data) else { return nil }
        let secondsSinceSwiftReferenceDate =
            secondsSinceDotNetReferenceDate - Date.secondsBetweenSwiftAndDotNetReferenceDates
        self = Date(timeIntervalSinceReferenceDate: Double(secondsSinceSwiftReferenceDate))
    }
    
    func iso8601String() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter.string(from: self)
    }
    
    func base64EncodedString() -> String {
        let secondsSinceSwiftReferenceDate = Int64(self.timeIntervalSinceReferenceDate)
        let secondsSinceDotNetReferenceDate =
            secondsSinceSwiftReferenceDate + Date.secondsBetweenSwiftAndDotNetReferenceDates
        return secondsSinceDotNetReferenceDate.data.base64EncodedString()
    }
    
    var iso8601WeekOfYear: Int {
        let isoCalendar = Calendar(identifier: .iso8601)
        let dateComponents = isoCalendar.dateComponents([.weekOfYear], from: self)
        return dateComponents.weekOfYear ?? 0
    }
}
