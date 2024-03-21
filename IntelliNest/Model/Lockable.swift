//
//  Lockable.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import SwiftUI

protocol Lockable {
    var id: LockID { get }
    var lockState: LockState { get set }
    var isLoading: Bool { get }
    var actionText: String { get }
    var expectedState: LockState { get set }
    var expectedStateSetDate: Date? { get set }
    var expectedStateIsOld: Bool { get }
    var isActive: Bool { get }
    var image: Image { get }
    func stateToString() -> String
}

extension Lockable {
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
        default:
            "Lås upp"
        }
    }

    var isLoading: Bool {
        (expectedState != .unknown && lockState != expectedState) || (lockState == .unknown && !expectedStateIsOld)
    }

    var isActive: Bool {
        [.unlocked, .unlocking, .locking].contains(lockState)
    }

    var expectedStateIsOld: Bool {
        if let setDate = expectedStateSetDate {
            Date().timeIntervalSince(setDate) > 30
        } else {
            false
        }
    }

    var image: Image {
        if lockState == .locked || lockState == .unlocking {
            Image(systemImageName: .locked)
        } else if lockState == .unlocked || lockState == .locking {
            Image(systemImageName: .unlocked)
        } else {
            Image(systemImageName: .lockSlash)
        }
    }

    func stateToString() -> String {
        switch lockState {
        case .locked:
            "låst"
        case .unlocked:
            "olåst"
        case .unlocking:
            "låser upp"
        case .locking:
            "låser"
        default:
            lockState.rawValue
        }
    }
}
