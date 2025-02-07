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

    var humanReadable: String {
        let now = Date()
        let calendar = Calendar.current

        if let minutesAgo = calendar.dateComponents([.minute], from: self, to: now).minute, minutesAgo < 60 {
            if minutesAgo == 0 {
                return "Just now"
            } else if minutesAgo == 1 {
                return "\(minutesAgo) minute ago"
            } else {
                return "\(minutesAgo) minutes ago"
            }
        }

        if let hoursAgo = calendar.dateComponents([.hour], from: self, to: now).hour, hoursAgo < 24 {
            return "\(hoursAgo) \(hoursAgo == 1 ? "hour" : "hours") ago"
        }

        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }

    func minutesLeft() -> Int {
        let timeZoneOffset = TimeZone.current.secondsFromGMT()
        let selfInLocalTimezone = addingTimeInterval(TimeInterval(timeZoneOffset))
        let now = Date().addingTimeInterval(TimeInterval(timeZoneOffset))
        return Calendar.current.dateComponents([.minute], from: now, to: selfInLocalTimezone).minute ?? -1
    }
}
