//
//  VariableValue.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-17.
//

import Foundation

enum ServiceValues: Encodable {
    case string(String)
    case double(Double)
    case stringArray([String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let stringValue):
            try container.encode(stringValue)
        case .double(let doubleValue):
            try container.encode(doubleValue)
        case .stringArray(let stringArrayValue):
            try container.encode(stringArrayValue)
        }
    }
}
