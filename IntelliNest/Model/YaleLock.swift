//
//  YaleLock.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import Foundation

struct YaleLock: Lockable, Decodable {
    var expectedStateSetDate: Date?
    let id: LockID
    var lockState: LockState = .unknown { didSet {
        if lockState == expectedState || expectedStateIsOld {
            expectedState = .unknown
        }
    }}
    var expectedState: LockState = .unknown {
        didSet {
            self.expectedStateSetDate = Date()
        }
    }

    var doorState: DoorState = .closed
}
