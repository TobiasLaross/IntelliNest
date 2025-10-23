//
//  CalendarExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-08.
//

import Foundation

extension Calendar {
    static var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    static var currentQuarter: Int {
        let now = Date()
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        return max(0, min(95, hour * 4 + minute / 15))
    }
}
