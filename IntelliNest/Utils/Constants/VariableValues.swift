//
//  VariableValues.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-17.
//

import Foundation

enum VariableValue: Encodable {
    case string(String)
    case double(Double)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let stringValue):
            try container.encode(stringValue)
        case .double(let doubleValue):
            try container.encode(doubleValue)
        }
    }
}
