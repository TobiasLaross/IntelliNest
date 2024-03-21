//
//  HomeViewModelExtension+LockServiceProtocol.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-23.
//

import Foundation
import ShipBookSDK

extension HomeViewModel: LockServiceProtocol {
    func toggleStateForSideDoor() {
        guard let capturedLock = getUpdatedLock(sideDoor) else {
            return
        }
        Task { @MainActor in
            let action: Action = sideDoor.lockState == .unlocked ? .lock : .unlock
            sideDoor.expectedState = capturedLock.expectedState
            let success = await yaleApiService.setLockState(lockID: capturedLock.id, action: action)
            if success {
                sideDoor.lockState = capturedLock.expectedState
            }
            sideDoor.expectedState = .unknown
        }
    }

    func toggleStateForFrontDoor() {
        guard let capturedLock = getUpdatedLock(frontDoor) else {
            return
        }
        Task { @MainActor in
            let action: Action = frontDoor.lockState == .unlocked ? .lock : .unlock
            frontDoor.expectedState = capturedLock.expectedState
            let success = await yaleApiService.setLockState(lockID: capturedLock.id, action: action)
            if success {
                frontDoor.lockState = capturedLock.expectedState
            }
            frontDoor.expectedState = .unknown
        }
    }

    private func getUpdatedLock(_ lock: Lockable) -> Lockable? {
        var lockToUpdate = lock
        switch lock.lockState {
        case .unlocked:
            lockToUpdate.expectedState = .locked
        case .locked:
            lockToUpdate.expectedState = .unlocked
        default:
            Log.warning("Trying to toggle from bad initial state: \(lock.lockState)")
            return nil
        }

        return lockToUpdate
    }
}
