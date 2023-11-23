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
        let washerCompletionInMInutes = washerCompletionTime.date.minutesLeft()
        if washerCompletionInMInutes >= 0 && washerState.state != "none" {
            text.addNewLineAndappend("Tvätten klar om \(timeRemainingFormatter(minutesRemaining: washerCompletionInMInutes))")
        }

        let dryerCompletionInMInutes = dryerCompletionTime.date.minutesLeft()
        if dryerCompletionInMInutes >= 0 && dryerState.state != "none" {
            text.addNewLineAndappend("Torktumlaren klar om \(timeRemainingFormatter(minutesRemaining: dryerCompletionInMInutes))")
        }

        if let chargingPower = Double(easeeCharger.state), chargingPower > 0 {
            text.addNewLineAndappend("Laddbox: \(chargingPower)kW")
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
