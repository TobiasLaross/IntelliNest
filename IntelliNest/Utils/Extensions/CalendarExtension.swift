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
}
