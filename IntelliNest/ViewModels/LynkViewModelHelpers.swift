import SwiftUI

extension LynkViewModel {
    var buttonSize: CGFloat {
        75
    }

    var lynkClimateTitle: String {
        isLynkAirConditionActive || isLynkAirConditionLoading ? "Stäng av" : "Starta"
    }

    var lynkChargerConnectionDescription: String {
        if lynkChargerState.state == "Charging" {
            "laddar"
        } else if lynkChargerConnectionStatus.state == "Power Not Activated" || lynkChargerConnectionStatus.state == "Connected" {
            "är inkopplad med ström tillgänglig"
        } else if lynkChargerConnectionStatus.state == "Disconnected" {
            "är inte inkopplad"
        } else {
            "connection: \(lynkChargerConnectionStatus.state) charger: \(lynkChargerState.state)"
        }
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
        isLynkUnlocked ? "Lås" : "Lås upp"
    }

    var doorLockIcon: Image {
        isLynkUnlocked ? .init(systemImageName: .unlocked) : .init(systemImageName: .locked)
    }

    var flashLightTitle: String {
        isLynkFlashing ? "Stäng av" : "Starta"
    }

    var flashLightIcon: Image {
        isLynkFlashing ? .init(systemImageName: .lightbulbSlash) : .init(systemImageName: .headLightBeam)
    }

    var isCharging: Bool {
        lynkChargerState.state == "Charging"
    }

    var chargerStateDescription: String {
        isCharging ? "Laddar, \(lynkTimeUntilCharged.state)min kvar" : "Laddar inte"
    }

    var lynkLastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        let date = max(doorLockUpdatedAt.date, lynkCarUpdatedAt.date)
        return date.humanReadable
        // return formatter.string(from: date)
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
