//
//  DateExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-03-05.
//

import Foundation

extension Date {
    static func fromISO8601(_ dateString: String?) -> Date? {
        guard let dateString else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        return dateFormatter.date(from: dateString)
    }

    func minutesLeft() -> Int {
        let timeZoneOffset = TimeZone.current.secondsFromGMT()
        let selfInLocalTimezone = self.addingTimeInterval(TimeInterval(timeZoneOffset))
        let now = Date().addingTimeInterval(TimeInterval(timeZoneOffset))
        return Calendar.current.dateComponents([.minute], from: now, to: selfInLocalTimezone).minute ?? -1
    }
}
