//
//  StringExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-22.
//

import Foundation

extension String {
    func toKW() -> String {
        if let doubleValue = Double(self) {
            let kiloWatt = doubleValue / 1000.0
            return kiloWatt == 0 ? "\(Int(kiloWatt))kW" : String(format: "%.1fkW", kiloWatt)
        } else {
            return "?kW"
        }
    }

    func toKWh() -> String {
        if let kiloWattHours = Double(self) {
            return kiloWattHours == 0 ? "\(Int(kiloWattHours))kWh" : String(format: "%.1fkWh", kiloWattHours)
        } else {
            return "?kWh"
        }
    }

    func toOre() -> String {
        if let doubleValue = Double(self) {
            let ore = Int(doubleValue * 100)
            return "\(ore) Öre"
        } else {
            return "? Öre"
        }
    }

    mutating func addNewLineAndappend(_ other: String) {
        if isNotEmpty {
            append("\n")
        }

        append(other)
    }
}
