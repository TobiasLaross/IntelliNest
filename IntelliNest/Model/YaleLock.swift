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
    var isReading = false

    /// Unknown alone does not mean busy: a lock we failed to read must stay tappable so the user can ask
    /// for another read, so only a read in flight or an unconfirmed toggle counts as loading.
    var isLoading: Bool {
        (expectedState != .unknown && lockState != expectedState) || isReading
    }

    /// A tap on an unknown door only reads it, so the button must not promise to unlock it.
    var actionText: String {
        switch lockState {
        case .unlocked:
            "Lås"
        case .unlocking:
            "Låser upp"
        case .locking:
            "Låser"
        case .locked:
            "Lås upp"
        case .unknown:
            "Uppdatera"
        }
    }
}
