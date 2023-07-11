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
    var yaleApiService: YaleApiService { get }
    func toggleStateForSideDoor()
    func toggleStateForFrontDoor()
}
