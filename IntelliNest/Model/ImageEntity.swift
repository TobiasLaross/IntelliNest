//
//  ImageEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2023-12-11.
//

import Foundation

struct ImageEntity {
    let entityID: EntityId
    var state = ""
    var urlPath = ""

    init(entityID: EntityId) {
        self.entityID = entityID
    }
}
