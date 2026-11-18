//
//  HomeViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-20.
//

import CoreLocation
import Foundation
import SwiftUI
import UIKit

@MainActor
class HomeViewModel: ObservableObject, Reloadable {
    static let expectedStateAttempts = 20
    static let expectedStatePollInterval: CGFloat = 0.5

    @Published var sideDoor = YaleLock(id: .sideDoor)
    @Published var frontDoor = YaleLock(id: .frontDoor)
    @Published var storageLock = LockEntity(entityId: .storageLock)
    @Published var allLights = LightEntity(entityId: .allLights)
    @Published var coffeeMachine = SwitchEntity(entityId: .coffeeMachine)
    @Published var sarahsIphone = Entity(entityId: .hittaSarahsIphone)
    @Published var shouldShowCoffeeMachineScheduling = false
    @Published var coffeeMachineStartTime = Entity(entityId: .coffeeMachineStartTime)
    @Published var coffeeMachineStartTimeEnabled = Entity(entityId: .coffeeMachineStartTimeEnabled)
    @Published var pulsePower = Entity(entityId: .pulsePower)
    @Published var tibberPrice = Entity(entityId: .tibberPrice)
    @Published var pulseConsumptionToday = Entity(entityId: .pulseConsumptionToday)
    @Published var solarProductionToday = Entity(entityId: .solarProductionToday)
    @Published var washerCompletionTime = Entity(entityId: .washerCompletionTime)
    @Published var washerState = Entity(entityId: .washerState)
    @Published var dryerCompletionTime = Entity(entityId: .dryerCompletionTime)
    @Published var dryerState = Entity(entityId: .dryerState)
    @Published var easeePower = Entity(entityId: .easeePower)
    @Published var easeeNoCurrentReason = Entity(entityId: .easeeNoCurrentReason)
    @Published var easeeStatus = Entity(entityId: .easeeStatus)
    @Published var generalWasteDate = Entity(entityId: .generalWasteDate)
    @Published var plasticWasteDate = Entity(entityId: .plasticWasteDate)
    @Published var gardenWasteDate = Entity(entityId: .gardenWasteDate)

    @Published var noLocationAccess = false

    var isReloading = false
    /// Handle on the read a tap on an unreadable lock starts, so tests can await it.
    private(set) var pendingLockRefreshTask: Task<Void, Never>?
    private var lockReadGenerations: [LockID: Int] = [:]
    let entityIDs: [EntityId] = [
        .hittaSarahsIphone, .coffeeMachine, .storageLock, .coffeeMachineStartTime, .coffeeMachineStartTimeEnabled,
        .pulsePower, .tibberPrice, .pulseConsumptionToday, .washerCompletionTime,
        .solarProductionToday, .dryerCompletionTime, .washerState, .dryerState, .easeePower, .easeeNoCurrentReason,
        .easeeStatus, .generalWasteDate, .plasticWasteDate, .gardenWasteDate, .allLights
    ]

    var isEaseeCharging: Bool {
        easeeStatus.state.lowercased() == "charging"
    }

    var isEaseeAwaitingSchedule: Bool {
        easeeNoCurrentReason.state.lowercased() == "pending_schedule" || easeeStatus.state.lowercased() == "awaiting_start"
    }

    var chargingIcon: Image {
        isEaseeAwaitingSchedule ? .init(systemImageName: .evChargerSlash) : .init(systemImageName: .evCharger)
    }

    private var restAPIService: RestAPIService
    private let locationManager = CLLocationManager()
    let yaleApiService: YaleApiService
    var urlCreator: URLCreator
    let showHeatersAction: MainActorVoidClosure
    let showLynkAction: MainActorVoidClosure
    let showPowerGridAction: MainActorVoidClosure
    let showLightsAction: MainActorVoidClosure
    let showMusicAction: MainActorVoidClosure
    private(set) var toolbarReloadAction: MainActorAsyncVoidClosure

    init(restAPIService: RestAPIService,
         yaleApiService: YaleApiService,
         urlCreator: URLCreator,
         showHeatersAction: @escaping MainActorVoidClosure,
         showLynkAction: @escaping MainActorVoidClosure,
         showPowerGridAction: @escaping MainActorVoidClosure,
         showLightsAction: @escaping MainActorVoidClosure,
         showMusicAction: @escaping MainActorVoidClosure,
         toolbarReloadAction: @escaping MainActorAsyncVoidClosure) {
        self.restAPIService = restAPIService
        self.yaleApiService = yaleApiService
        self.urlCreator = urlCreator
        self.showHeatersAction = showHeatersAction
        self.showLynkAction = showLynkAction
        self.showPowerGridAction = showPowerGridAction
        self.showLightsAction = showLightsAction
        self.showMusicAction = showMusicAction
        self.toolbarReloadAction = toolbarReloadAction
    }

    func reload() async {
        await withReloadGuard {
            let service = self.restAPIService
            await withTaskGroup(of: (EntityId, Entity)?.self) { group in
                for entityID in self.entityIDs {
                    group.addTask {
                        do {
                            let entity = try await service.reloadState(entityID: entityID)
                            return (entityID, entity)
                        } catch {
                            Log.error("Failed to reload entity: \(entityID): \(error)")
                            return nil
                        }
                    }
                }

                for await result in group {
                    if let (entityID, entity) = result {
                        self.reload(entityID: entityID, state: entity.state, lastChanged: entity.lastChanged)
                    }
                }
            }
        }
    }

    func turnOffAllLights() {
        restAPIService.update(lightIDs: [.allLights], action: .turnOff, brightness: 0, reloadTimes: 4)
    }

    func toggleStateForSarahsIphone() {
        let action: Action = sarahsIphone.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: .hittaSarahsIphone, domain: .script, action: action, reloadTimes: 7)
    }

    func toggleCoffeeMachine() {
        let action: Action = coffeeMachine.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: .coffeeMachine, domain: .switchDomain, action: action, reloadTimes: 2)
    }

    func toggleEaseeCharging() {
        restAPIService.callScript(scriptID: .easeeToggle, reloadTimes: 2)
    }

    func showCoffeeMachineScheduling() {
        Task { @MainActor in
            if !coffeeMachineStartTimeEnabled.isActive {
                toggleCoffeeMachineStarTimeEnabled()
            }

            shouldShowCoffeeMachineScheduling = true
        }
    }

    func updateDateTimeEntity(entity: Entity) {
        restAPIService.update(dateEntityID: entity.entityId, date: entity.date)
    }

    func toggleCoffeeMachineStarTimeEnabled() {
        let action: Action = coffeeMachineStartTimeEnabled.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: .coffeeMachineStartTimeEnabled, domain: .inputBoolean, action: action, reloadTimes: 2)
    }

    func toggleStateForStorageLock() {
        let action: Action = storageLock.lockState == .unlocked ? .lock : .unlock
        storageLock.expectedState = action == .lock ? .locked : .unlocked
        restAPIService.update(entityID: .storageLock, domain: .lock, action: action, reloadTimes: 6)
    }

    func lockStorage() {
        storageLock.expectedState = .locked
        restAPIService.update(entityID: .storageLock, domain: .lock, action: .lock, reloadTimes: 6)
    }

    func unlockStorage() {
        storageLock.expectedState = .unlocked
        restAPIService.update(entityID: .storageLock, domain: .lock, action: .unlock, reloadTimes: 6)
    }

    func resetExpectedLockStates() {
        storageLock.expectedState = .unknown
        frontDoor.expectedState = .unknown
        sideDoor.expectedState = .unknown
    }

    func checkLocationAccess() {
        Task { @MainActor in
            noLocationAccess = locationManager.authorizationStatus != .authorizedAlways
        }
    }

    func openLocationSettings() {
        Task { @MainActor in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }

            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            }
        }
    }

    private lazy var entityKeyPaths: [EntityId: ReferenceWritableKeyPath<HomeViewModel, Entity>] = [
        .hittaSarahsIphone: \.sarahsIphone,
        .coffeeMachineStartTime: \.coffeeMachineStartTime,
        .coffeeMachineStartTimeEnabled: \.coffeeMachineStartTimeEnabled,
        .pulsePower: \.pulsePower,
        .tibberPrice: \.tibberPrice,
        .pulseConsumptionToday: \.pulseConsumptionToday,
        .solarProductionToday: \.solarProductionToday,
        .washerCompletionTime: \.washerCompletionTime,
        .washerState: \.washerState,
        .dryerCompletionTime: \.dryerCompletionTime,
        .dryerState: \.dryerState,
        .easeePower: \.easeePower,
        .easeeNoCurrentReason: \.easeeNoCurrentReason,
        .easeeStatus: \.easeeStatus,
        .generalWasteDate: \.generalWasteDate,
        .plasticWasteDate: \.plasticWasteDate,
        .gardenWasteDate: \.gardenWasteDate
    ]

    /// Yale has no push, so the only moment its state is worth chasing is right after we asked for a
    /// change: keep reading until the lock reports what we asked for, then stop. Every other refresh
    /// comes from the screen appearing or the reload button, not a timer.
    func reloadLockUntilExpectedState(lockID: LockID,
                                      attempts: Int = HomeViewModel.expectedStateAttempts,
                                      pollInterval: CGFloat = HomeViewModel.expectedStatePollInterval) async {
        for _ in 0 ..< attempts {
            if pollInterval > 0 {
                try? await Task.sleep(seconds: pollInterval)
            }
            switch lockID {
            case .frontDoor:
                frontDoor.lockState = await reload(lockID: frontDoor.id)
                if !frontDoor.isLoading { return }
            case .sideDoor:
                sideDoor.lockState = await reload(lockID: sideDoor.id)
                if !sideDoor.isLoading { return }
            case .storageDoor, .lynkDoor:
                Log.error("Tried to reload unhandled lock: \(lockID)")
                return
            }
        }
    }

    /// A write straight to the Yale cloud is the fast path from the phone, but it is also the one that
    /// fails - it timed out 218 times while the side door battery was dying. Home Assistant reaches the
    /// same locks over the LAN, so it stands in when the direct write does not land.
    func setLockState(lockID: LockID, action: Action) async -> Bool {
        if await yaleApiService.setLockState(lockID: lockID, action: action) {
            return true
        }
        guard let entityID = lockID.homeAssistantEntityID else {
            return false
        }
        Log.warning("Yale write failed for \(lockID), falling back to Home Assistant")
        return await restAPIService.setState(for: entityID, in: .lock, using: action, reloadTimes: 0)
    }

    private func reload(lockID: LockID) async -> LockState {
        do {
            return try await yaleApiService.getLockState(lockID: lockID)
        } catch {
            Log.error("Failed to load \(lockID) with error: \(error)")
            return .unknown
        }
    }

    func reload(entityID: EntityId, state: String, lastChanged: Date? = nil) {
        if let keyPath = entityKeyPaths[entityID] {
            self[keyPath: keyPath].state = state
        } else if entityID == .allLights {
            allLights.state = state
        } else if entityID == .coffeeMachine {
            coffeeMachine.state = state
            if let lastChanged {
                coffeeMachine.lastChanged = lastChanged
            }
        } else if entityID == .storageLock {
            storageLock.state = state
        } else {
            Log.error("HomeViewModel doesn't reload entityID: \(entityID)")
        }
    }
}

// MARK: - Yale lock reads

extension HomeViewModel {
    func reloadYaleLocks() async {
        await readLock(at: \.sideDoor)
        await readLock(at: \.frontDoor)
    }

    /// Reads overlap toggles and other reads of the same door, and a slow response from before a toggle
    /// would publish a state the toggle has already moved past. Each read takes a generation and only
    /// publishes while it is still the newest thing that happened to that lock.
    @discardableResult
    private func readLock(at keyPath: ReferenceWritableKeyPath<HomeViewModel, YaleLock>) async -> LockState? {
        let lockID = self[keyPath: keyPath].id
        let generation = bumpLockGeneration(lockID)
        self[keyPath: keyPath].isReading = true
        let lockState = await reload(lockID: lockID)
        guard lockReadGenerations[lockID] == generation else {
            return nil
        }
        self[keyPath: keyPath].isReading = false
        self[keyPath: keyPath].lockState = lockState
        return lockState
    }

    /// Called when a toggle starts, so any read already in flight for that door is dropped on arrival.
    func discardPendingLockReads(at keyPath: ReferenceWritableKeyPath<HomeViewModel, YaleLock>) {
        bumpLockGeneration(self[keyPath: keyPath].id)
        self[keyPath: keyPath].isReading = false
    }

    @discardableResult
    private func bumpLockGeneration(_ lockID: LockID) -> Int {
        let generation = (lockReadGenerations[lockID] ?? 0) + 1
        lockReadGenerations[lockID] = generation
        return generation
    }

    /// A tap on a lock we could not read asks for a read, not for the bolt to move: the user had no state
    /// to decide on, and toggling on a fresh read could unlock a door they never saw as locked.
    func refreshUnreadableLock(at keyPath: ReferenceWritableKeyPath<HomeViewModel, YaleLock>) {
        pendingLockRefreshTask = Task { @MainActor in
            let lockID = self[keyPath: keyPath].id
            if await readLock(at: keyPath) == .unknown {
                Log.warning("\(lockID) is still unknown after a tap-triggered reload")
                restAPIService.setErrorBannerText("Kunde inte läsa låset", "Försök igen om en stund")
            }
        }
    }
}
