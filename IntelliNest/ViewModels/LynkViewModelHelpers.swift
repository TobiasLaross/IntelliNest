import SwiftUI

extension LynkViewModel {
    var isEaseeCharging: Bool {
        easeeIsEnabled.isActive
    }

    var lynkClimateTitle: String {
        isLynkAirConditionActive || isLynkAirConditionLoading ? "Stäng av" : "Starta"
    }

    var lynkClimateUpdatedAtDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM HH:mm"
        return dateFormatter.string(from: lynkClimateUpdatedAt.date)
    }

    var addressUpdatedAtDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM HH:mm"
        return dateFormatter.string(from: max(addressUpdatedAt.date, doorLockUpdatedAt.date))
    }

    var batteryUpdatedAtDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM HH:mm"
        return dateFormatter.string(from: batteryUpdatedAt.date)
    }

    var fuelUpdatedAtDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM HH:mm"
        return dateFormatter.string(from: fuelUpdatedAt.date)
    }

    var chargerUpdatedAtDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM HH:mm"
        return dateFormatter.string(from: chargerUpdatedAt.date)
    }

    var engineTitle: String {
        isEngineRunning.isActive || isEngineLoading ? "Stäng av" : "Starta"
    }

    var isLynkAirConditionActive: Bool {
        lynkClimateHeating.isActive
    }

    var isLynkUnlocked: Bool {
        lynkDoorLock.lockState == .unlocked
    }

    var isLynkAirConditionLoading: Bool {
        !isLynkAirConditionActive && (lynkAirConditionInitiatedTime?.addingTimeInterval(5 * 60) ?? Date.distantPast) > Date()
    }

    var isEngineLoading: Bool {
        !isEngineRunning.isActive && (engineInitiatedTime?.addingTimeInterval(5 * 60) ?? Date.distantPast) > Date()
    }

    var doorLockTitle: String {
        isLynkUnlocked ? "Lås dörrarna" : "Lås upp dörrarna"
    }

    var doorLockIcon: Image {
        isLynkUnlocked ? .init(systemImageName: .unlocked) : .init(systemImageName: .locked)
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

    var isCharging: Bool {
        lynkChargerState.state == "Charging"
    }

    var chargerStateDescription: String {
        isCharging ? "Laddar, \(lynkTimeUntilCharged.state)min kvar" : "Laddar inte"
    }

    var chargingIcon: Image {
        isEaseeCharging ? .init(systemImageName: .xmarkCircle) : .init(systemImageName: .boltCar)
    }

    var lynkLastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        let date = max(doorLockUpdatedAt.date, lynkCarUpdatedAt.date)
        return formatter.string(from: date)
    }

    var lynkClimateIconColor: Color {
        isLynkAirConditionActive ? .yellow : .white
    }

    var leafClimateTitle: String {
        isLeafAirConditionActive || isLeafAirConditionLoading ? "Stäng av" : "Starta"
    }

    var isLeafAirConditionActive: Bool {
        leafClimateTimerRemaining != nil
    }

    var isLeafAirConditionLoading: Bool {
        !isLeafAirConditionActive && (leafAirConditionInitiatedTime?.addingTimeInterval(5 * 60) ?? Date.distantPast) > Date()
    }

    var leafClimateIconColor: Color {
        isLeafAirConditionActive ? .yellow : .white
    }

    var leafClimateTimerRemaining: Int? {
        let formatter = ISO8601DateFormatter()
        let timerDate = leafClimateTimer.state.lowercased() != "unavailable"
            ? formatter.date(from: leafClimateTimer.state)
            : nil
        if let minutes = timerDate?.minutesLeft(), minutes >= 0 {
            return minutes
        }
        return nil
    }
}
