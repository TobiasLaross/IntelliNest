//
//  HomeViewModelExtension+LockServiceProtocol.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-23.
//

import Foundation

extension HomeViewModel: LockServiceProtocol {
    func toggleStateForSideDoor() {
        toggleYaleLock(at: \.sideDoor)
    }

    func toggleStateForFrontDoor() {
        toggleYaleLock(at: \.frontDoor)
    }

    private func toggleYaleLock(at keyPath: ReferenceWritableKeyPath<HomeViewModel, YaleLock>) {
        guard let capturedLock = getUpdatedLock(self[keyPath: keyPath]) else {
            return
        }
        Task { @MainActor in
            let action: Action = capturedLock.expectedState == .locked ? .lock : .unlock
            self[keyPath: keyPath].expectedState = capturedLock.expectedState
            guard await setLockState(lockID: capturedLock.id, action: action) else {
                self[keyPath: keyPath].expectedState = .unknown
                return
            }
            // The lock takes a couple of seconds to actually throw the bolt, so read it back rather than
            // assuming the write means it is done - the state we show should be the state it reports.
            await reloadLockUntilExpectedState(lockID: capturedLock.id)
            self[keyPath: keyPath].expectedState = .unknown
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
