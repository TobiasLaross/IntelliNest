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

    func daysRemainingDescription() -> String? {
        let currentDate = Calendar.current.startOfDay(for: Date())
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: currentDate, to: self)

        if let daysRemaining = components.day {
            switch daysRemaining {
            case 0:
                return "idag"
            case 1:
                return "imorgon"
            default:
                break
            }
        }

        return nil
    }

    func minutesLeft() -> Int {
        let timeZoneOffset = TimeZone.current.secondsFromGMT()
        let selfInLocalTimezone = addingTimeInterval(TimeInterval(timeZoneOffset))
        let now = Date().addingTimeInterval(TimeInterval(timeZoneOffset))
        return Calendar.current.dateComponents([.minute], from: now, to: selfInLocalTimezone).minute ?? -1
    }
}
