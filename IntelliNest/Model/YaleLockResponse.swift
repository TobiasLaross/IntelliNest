//
//  YaleLockResponse.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import Foundation

struct LockStatus: Decodable {
    let status: String
    let dateTime: String
    let isLockStatusChanged: Bool
    let valid: Bool
    let doorState: DoorState
}

struct YaleLockResponse: Decodable {
    let lockStatus: LockStatus

    enum CodingKeys: String, CodingKey {
        case lockStatus = "LockStatus"
    }
}
