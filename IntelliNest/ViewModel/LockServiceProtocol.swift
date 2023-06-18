//
//  LockServiceProtocol.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-23.
//

import Foundation
import ShipBookSDK

protocol LockServiceProtocol {
    var sideDoor: YaleLock { get set }
    var frontDoor: YaleLock { get set }
    var storageLock: LockEntity { get set }
    var hassApiService: HassApiService { get }
    var yaleApiService: YaleApiService { get }
    func toggleStateForSideDoor()
    func toggleStateForFrontDoor()
    func toggleStateForStorageLock()
    func lock(lockEntity: inout LockEntity)
    func unlock(lockEntity: inout LockEntity)
}
