//
//  HomeViewModelExtension.swift
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

    func toggleStateForStorageLock() {
        guard let capturedLock = getUpdatedLock(storageLock) else {
            return
        }
        Task { @MainActor in
            let action: Action = storageLock.lockState == .unlocked ? .lock : .unlock
            storageLock.expectedState = capturedLock.expectedState
            await hassApiService.setStateFor(lock: storageLock, action: action)
            await reloadLockUntilExpectedState(lockID: storageLock.id)
        }
    }

    func lock(lockEntity: inout LockEntity) {
        let action = Action.lock
        lockEntity.expectedState = .locked
        let lockToUpdate = lockEntity
        Task { @MainActor in
            await hassApiService.setStateFor(lock: lockToUpdate, action: action)
            await reloadLockUntilExpectedState(lockID: lockToUpdate.id)
        }
    }

    func unlock(lockEntity: inout LockEntity) {
        let action = Action.unlock
        lockEntity.expectedState = .unlocked
        let lockToUpdate = lockEntity
        Task { @MainActor in
            await hassApiService.setStateFor(lock: lockToUpdate, action: action)
            await reloadLockUntilExpectedState(lockID: lockToUpdate.id)
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
