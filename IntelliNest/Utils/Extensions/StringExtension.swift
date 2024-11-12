//
//  StringExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-22.
//

import Foundation

extension String {
    var removingHTTPSchemeAndTrailingSlash: String {
        replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "").removingTrailingSlash
    }

    var removingTrailingSlash: String {
        if hasSuffix("/") {
            return String(dropLast())
        }
        return self
    }

    var toKW: String {
        if let doubleValue = Double(self) {
            doubleValue.toKWString
        } else {
            "?kW"
        }
    }

    var toKWh: String {
        if let kiloWattHours = Double(self) {
            let rounded = kiloWattHours.roundedWithOneDecimal
            return kiloWattHours == 0 ? "\(Int(rounded))kWh" : String(format: "%.1fkWh", rounded)
        } else {
            return "?kWh"
        }
    }

    var toOre: String {
        if let doubleValue = Double(self) {
            let ore = Int(round(doubleValue * 100))
            return "\(ore) Öre"
        } else {
            return "? Öre"
        }
    }

    var toKr: String {
        if let doubleValue = Double(self) {
            "\(doubleValue.roundedWithOneDecimal) Kr"
        } else {
            "? Kr"
        }
    }

    var roundedWithOneDecimal: Double {
        if let doubleValue = Double(self) {
            doubleValue.roundedWithOneDecimal
        } else {
            0
        }
    }

    mutating func addNewLineAndAppend(_ other: String) {
        if isNotEmpty {
            append("\n")
        }

        append(other)
    }
}
