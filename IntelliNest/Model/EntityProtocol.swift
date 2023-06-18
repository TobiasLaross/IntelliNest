//
//  EntityProtocol.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-08.
//

import Foundation

protocol EntityProtocol: Decodable, Equatable {
    var entityId: EntityId { get set }
    var state: String { get set }
    var nextUpdate: NSDate { get set }
    var isActive: Bool { get }

    mutating func setNextUpdateTime()
    func canUpdate() -> Bool
}

extension EntityProtocol {
    func canUpdate() -> Bool {
        if nextUpdate.timeIntervalSinceNow < 0 {
            return true
        } else {
            return false
        }
    }
}
