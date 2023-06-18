//
//  DateExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-03-05.
//

import Foundation

extension Date {
    static func fromISO8601(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        return dateFormatter.date(from: dateString)
    }
}
