//
//  Navigator+Geofence.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-03.
//

import Foundation
import UIKit

/// Geofence-driven lock handling. Split out of `Navigator` to keep that file under the 400-line limit.
extension Navigator {
    func didEnterHome() {
        startGeofenceFlow(name: "Geofence-did-enter-home") { generation in
            await self.unlockAfterEnteringHome(generation: generation)
        }
    }

    func unlockAfterEnteringHome(generation: Int) async {
        let lastEnteredHomeTime = UserDefaults.shared.value(forKey: StorageKeys.enteredHomeTime.rawValue) as? Date
        UserDefaults.shared.setValue(Date.now, forKey: StorageKeys.enteredHomeTime.rawValue)
        guard let currentUserAwayEntityID = UserManager.currentUserAwayEntityID else {
            Log.warning("Geofence utan användare: \(UserManager.currentUser)")
            return
        }
        do {
            if let lastEnteredHomeTime, Date.now.timeIntervalSince(lastEnteredHomeTime) < 10 * 60 {
                let userIsAway = try await restAPIService.get(entityId: currentUserAwayEntityID, entityType: Entity.self)
                guard userIsAway.isActive else {
                    Log.debug("Geofence användare redan hemma")
                    return
                }
            }
        } catch {
            Log.error("Failed to fetch user away status for \(currentUserAwayEntityID)")
        }

        NotificationService.sendNotification(title: "Välkommen hem",
                                             message: "",
                                             identifier: "Geofence-did-enter-home")
        guard isCurrentGeofenceGeneration(generation) else {
            return
        }
        let locksUpdated = await updateYaleLocks(with: .unlock)
        guard isCurrentGeofenceGeneration(generation) else {
            return
        }
        if !locksUpdated {
            // Presence is still written: Home Assistant's backup unlock triggers on this boolean
            // going off, so skipping it would disable the fallback in exactly the case it exists for.
            Log.warning("Geofence-upplåsning misslyckades, skriver ändå närvaro för att armera HA-backupen")
        }
        await restAPIService.setState(for: currentUserAwayEntityID, in: .inputBoolean, using: .turnOff)
    }

    func didExitHome() {
        startGeofenceFlow(name: "Geofence-did-exit-home") { generation in
            await self.lockAfterExitingHome(generation: generation)
        }
    }

    func lockAfterExitingHome(generation: Int) async {
        guard let currentUserAwayEntityID = UserManager.currentUserAwayEntityID else {
            Log.warning("Geofence utan användare: \(UserManager.currentUser)")
            return
        }
        guard isCurrentGeofenceGeneration(generation) else {
            return
        }
        if await !updateYaleLocks(with: .lock) {
            Log.warning("Geofence-låsning misslyckades för minst en dörr")
        }
        guard isCurrentGeofenceGeneration(generation) else {
            return
        }
        await restAPIService.setState(for: currentUserAwayEntityID, in: .inputBoolean, using: .turnOn)
    }

    @discardableResult
    func updateYaleLocks(with action: Action) async -> Bool {
        async let frontDoorWrite = homeViewModel.setLockState(lockID: .frontDoor, action: action)
        async let sideDoorWrite = homeViewModel.setLockState(lockID: .sideDoor, action: action)
        let (frontDoorSucceeded, sideDoorSucceeded) = await (frontDoorWrite, sideDoorWrite)
        return frontDoorSucceeded && sideDoorSucceeded
    }

    func startGeofenceFlow(name: String, _ work: @escaping (Int) async -> Void) {
        geofenceGeneration += 1
        let generation = geofenceGeneration
        geofenceTask?.cancel()
        geofenceTask = Task {
            await withBackgroundTask(name: name) {
                await work(generation)
            }
        }
    }

    func isCurrentGeofenceGeneration(_ generation: Int) -> Bool {
        guard generation == geofenceGeneration else {
            Log.warning("Ignorerar gammal geofence-händelse \(generation), aktuell är \(geofenceGeneration)")
            return false
        }
        return true
    }

    /// A geofence callback wakes the app with no runtime guarantee, and the Yale calls it makes are cloud
    /// round-trips that take seconds - long enough for iOS to suspend the process mid-request and strand
    /// them until they surface as timeouts. The Home Assistant calls in the same flow survive without this
    /// only because they are LAN requests that finish in milliseconds.
    func withBackgroundTask(name: String, _ work: () async -> Void) async {
        let application = UIApplication.shared
        var taskIdentifier = UIBackgroundTaskIdentifier.invalid
        taskIdentifier = application.beginBackgroundTask(withName: name) {
            application.endBackgroundTask(taskIdentifier)
            taskIdentifier = .invalid
        }

        await work()

        if taskIdentifier != .invalid {
            application.endBackgroundTask(taskIdentifier)
            taskIdentifier = .invalid
        }
    }
}

private extension UserManager {
    @MainActor
    static var currentUserAwayEntityID: EntityId? {
        switch currentUser {
        case .sarah:
            .sarahIsAway
        case .tobias:
            .tobiasIsAway
        default:
            nil
        }
    }
}
