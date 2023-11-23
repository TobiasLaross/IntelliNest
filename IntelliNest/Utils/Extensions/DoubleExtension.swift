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
}
