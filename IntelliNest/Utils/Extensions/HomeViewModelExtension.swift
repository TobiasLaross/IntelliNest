//
//  HomeViewModelExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-23.
//

import SwiftUI

extension HomeViewModel {
    var sarahIphoneimage: Image {
        if sarahsIphone.isActive {
            return Image(systemImageName: .iPhoneActive)
        } else {
            return Image(systemImageName: .iPhone)
        }
    }

    var dynamicInfoText: String {
        var text = ""
        let washerCompletionInMinutes = washerCompletionTime.date.minutesLeft()
        if washerCompletionInMinutes >= 0 && washerState.state.isRunning() {
            text.addNewLineAndAppend("Tvätten: \(timeRemainingFormatter(minutesRemaining: washerCompletionInMinutes))")
        }

        let dryerCompletionInMinutes = dryerCompletionTime.date.minutesLeft()
        if dryerCompletionInMinutes >= 0 && dryerState.state.isRunning() {
            text.addNewLineAndAppend("Torktumlaren: \(timeRemainingFormatter(minutesRemaining: dryerCompletionInMinutes))")
        }

        if let chargingPower = Double(easeeCharger.state), chargingPower > 0 {
            text.addNewLineAndAppend("Laddbox: \(chargingPower.roundedWithOneDecimal)kW")
        }

        if let generalWasteDescription = generalWasteDate.date.daysRemainingDescription() {
            text.addNewLineAndAppend("Restavfall töms \(generalWasteDescription)")
        }
        if let plasticWasteDescription = plasticWasteDate.date.daysRemainingDescription() {
            text.addNewLineAndAppend("Plast töms \(plasticWasteDescription)")
        }

        return text
    }

    private func timeRemainingFormatter(minutesRemaining: Int) -> String {
        if minutesRemaining >= 60 {
            let hours = minutesRemaining / 60
            let minutes = minutesRemaining % 60
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutesRemaining)min"
        }
    }
}

private extension String {
    func isRunning() -> Bool {
        self.lowercased() != "none"
    }
}
