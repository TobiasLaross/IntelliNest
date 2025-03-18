//
//  EntityProtocol.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-08.
//

import Foundation

protocol EntityProtocol: Decodable, Equatable {
    var entityId: EntityId { get }
    var state: String { get set }
    var nextUpdate: Date { get set }
    var isActive: Bool { get }

    mutating func setNextUpdateTime()
    func canUpdate() -> Bool
}

extension EntityProtocol {
    func canUpdate() -> Bool {
        if nextUpdate.timeIntervalSinceNow < 0 {
            true
        } else {
            false
        }
    }

    mutating func setNextUpdateTime() {
        nextUpdate = Date().addingTimeInterval(0.5)
    }
}

struct EntityMinimized: Decodable {
    let state: String

    enum CodingKeys: String, CodingKey {
        case state
    }
}
