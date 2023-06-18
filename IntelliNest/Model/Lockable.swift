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
            return "Lås"
        case .unlocking:
            return "Låser upp"
        case .locking:
            return "Låser"
        case .locked:
            return "Lås upp"
        default:
            return "Lås upp"
        }
    }

    var isLoading: Bool {
        (expectedState != .unknown && lockState != expectedState) || (lockState == .unknown && !expectedStateIsOld)
    }

    var isActive: Bool {
        [.unlocked, .unlocking, .locking].contains(lockState)
    }

    var expectedStateIsOld: Bool {
        if let setDate = self.expectedStateSetDate {
            return Date().timeIntervalSince(setDate) > 30
        } else {
            return false
        }
    }

    var image: Image {
        if lockState == .locked || lockState == .unlocking {
            return Image(systemImageName: .locked)
        } else if lockState == .unlocked || lockState == .locking {
            return Image(systemImageName: .unlocked)
        } else {
            return Image(systemImageName: .lockSlash)
        }
    }

    func stateToString() -> String {
        switch lockState {
        case .locked:
            return "låst"
        case .unlocked:
            return "olåst"
        case .unlocking:
            return "låser upp"
        case .locking:
            return "låser"
        default:
            return lockState.rawValue
        }
    }
}
