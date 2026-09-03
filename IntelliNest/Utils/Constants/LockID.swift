//
//  LockID.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import Foundation

enum LockID: String, Decodable {
    case sideDoor = "7A274D712EF3B541A584EC739A0502A2"
    case frontDoor = "57034E453D405F4C8F9085C19EDF14D1"
    case storageDoor = "storage"
    case lynkDoor = "lynk"

    /// The same physical lock as Home Assistant sees it, used as the fallback path when a write straight
    /// to the Yale cloud fails. Only the two Yale doors have a counterpart.
    var homeAssistantEntityID: EntityId? {
        switch self {
        case .sideDoor: .sideDoorLock
        case .frontDoor: .frontDoorLock
        case .storageDoor, .lynkDoor: nil
        }
    }
}
