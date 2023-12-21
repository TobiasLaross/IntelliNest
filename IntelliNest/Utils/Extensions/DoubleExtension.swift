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

    var toKW: String {
        let kiloWatt = self / 1000.0
        let roundedKilowWatt = (abs(kiloWatt) < 0.06 ? 0 : kiloWatt).roundedWithOneDecimal
        return roundedKilowWatt == 0 ? "\(Int(roundedKilowWatt))kW" : String(format: "%.1fkW", roundedKilowWatt)
    }
}
