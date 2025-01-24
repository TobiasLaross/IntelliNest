import Foundation
import ShipBookSDK
import SwiftUI

@MainActor
class LeafViewModel: ObservableObject {
    @Published var climateRunning = Entity(entityId: .leafClimateRunning)
    @Published var climateTimer = Entity(entityId: .leafACTimer)
    @Published var battery = InputNumberEntity(entityId: .leafBattery)
    @Published var range = Entity(entityId: .leafRange)
    @Published var rangeAC = Entity(entityId: .leafRangeAC)
    @Published var easeeIsEnabled = Entity(entityId: .easeeIsEnabled)
    @Published var isCharging = Entity(entityId: .leafCharging)
    @Published var isPluggedIn = Entity(entityId: .leafPluggedIn)
    @Published var lastPoll = Entity(entityId: .leafLastPoll)

    @Published var airConditionInitiatedTime: Date?
    @Published var engineInitiatedTime: Date?
    @Published var isShowingHeaterOptions = false

    let entityIDs: [EntityId] = [
        .leafACTimer,
        .leafClimateRunning,
        .leafBattery,
        .leafCharging,
        .leafRange,
        .leafRangeAC,
        .leafLastPoll,
        .leafPluggedIn
    ]

    var isReloading = false
    var isLynkFlashing = false
    var isEaseeCharging: Bool {
        easeeIsEnabled.isActive
    }

    var climateTitle: String {
        isAirConditionActive || isAirConditionLoading ? "Stäng av" : "Starta"
    }

    var isAirConditionActive: Bool {
        climateRunning.isActive
    }

    var isAirConditionLoading: Bool {
        !isAirConditionActive && (airConditionInitiatedTime?.addingTimeInterval(5 * 60) ?? Date.distantPast) > Date()
    }

    var flashLightTitle: String {
        isLynkFlashing ? "Stäng av lamporna" : "Starta lamporna"
    }

    var flashLightIcon: Image {
        isLynkFlashing ? .init(systemImageName: .lightbulbSlash) : .init(systemImageName: .headLightBeam)
    }

    var chargingTitle: String {
        isEaseeCharging ? "Pausa Easee" : "Starta Easee"
    }

    var climateIconColor: Color {
        isAirConditionActive ? .yellow : .white
    }

    var restAPIService: RestAPIService
    private let repeatReloadAction: IntClosure

    init(restAPIService: RestAPIService, repeatReloadAction: @escaping IntClosure) {
        self.restAPIService = restAPIService
        self.repeatReloadAction = repeatReloadAction
    }

    func forceUpdate() {
        restAPIService.callService(serviceID: .leafUpdate, domain: .leaf)
        UserDefaults.shared.setValue(Date.now, forKey: StorageKeys.leafReloadTime.rawValue)
    }

    func reload() async {
        guard !isReloading else {
            return
        }

        isReloading = true
        let lastReloadTime = UserDefaults.shared.value(forKey: StorageKeys.leafReloadTime.rawValue) as? Date
        if (lastReloadTime?.addingTimeInterval(60 * 60) ?? Date.distantPast) < Date.now {
            forceUpdate()
            await reloadEntities()
            try? await Task.sleep(seconds: 5)
        }

        await reloadEntities()
        isReloading = false
    }

    private func reloadEntities() async {
        for entityID in entityIDs {
            do {
                let state = try await restAPIService.reloadState(entityID: entityID)
                reload(entityID: entityID, state: state)
            } catch {
                Log.error("Failed to reload entity: \(entityID): \(error)")
            }
        }
    }

    private func reload(entityID: EntityId, state: String, lastChanged: Date? = nil) {
        switch entityID {
        case .leafClimateRunning:
            climateRunning.state = state
            if let lastChanged {
                climateRunning.lastChanged = lastChanged
            }
        case .leafACTimer:
            climateTimer.state = state
        case .leafBattery:
            battery.state = state
        case .leafRange:
            range.state = state
        case .leafRangeAC:
            rangeAC.state = state
        case .easeeIsEnabled:
            easeeIsEnabled.state = state
        case .leafCharging:
            isCharging.state = state
        case .leafPluggedIn:
            isPluggedIn.state = state
        case .leafLastPoll:
            lastPoll.state = state
        default:
            Log.error("LeafViewModel doesn't reload entityID: \(entityID)")
        }
    }

    func toggleClimate() {
        if isAirConditionActive {
            stopClimate()
        } else {
            startClimate()
        }
    }

    func toggleEaseeCharging() {
        restAPIService.callScript(scriptID: .easeeToggle)
    }

    func startClimate() {
        airConditionInitiatedTime = Date()
        restAPIService.callService(serviceID: .leafStartClimate, domain: .leaf)
    }

    func stopClimate() {
        airConditionInitiatedTime = nil
        restAPIService.callService(serviceID: .leafStopClimate, domain: .leaf)
    }
}
