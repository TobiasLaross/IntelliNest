//
//  ServiceValues.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-17.
//

import Foundation

enum ServiceValues: Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case stringArray([String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(stringValue):
            try container.encode(stringValue)
        case let .int(intValue):
            try container.encode(intValue)
        case let .double(doubleValue):
            try container.encode(doubleValue)
        case let .stringArray(stringArrayValue):
            try container.encode(stringArrayValue)
        }
    }
}
