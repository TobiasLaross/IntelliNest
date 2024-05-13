//
//  DoubleExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-23.
//

import Foundation

extension Double {
    var roundedWithOneDecimal: Double {
        var temp = self * 10
        temp.round()
        return temp / 10
    }

    var toPercent: String {
        let roundedPercent = roundedWithOneDecimal
        return roundedPercent < 0.06 ? "0%" : "\(String(format: "%.1f", roundedPercent))%"
    }

    var toKW: String {
        let kiloWatt = self / 1000.0
        let roundedKilowWatt = (abs(kiloWatt) < 0.06 ? 0 : kiloWatt).roundedWithOneDecimal
        return roundedKilowWatt == 0 ? "\(Int(roundedKilowWatt))kW" : String(format: "%.1fkW", roundedKilowWatt)
    }

    var toFanSpeedPercentage: Double {
        if self == 0 {
            0
        } else if self == 1 {
            11
        } else {
            (self + 2) * 10
        }
    }

    var toFanSpeedTargetNumber: Double {
        switch self {
        case 11:
            1
        case 33:
            2
        case 44:
            3
        case 55:
            4
        case 66:
            5
        case 77:
            6
        case 88:
            7
        case 100:
            8
        default:
            0
        }
    }
}
