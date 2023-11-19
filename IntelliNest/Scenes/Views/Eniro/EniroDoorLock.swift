//
//  EniroDoorLock.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-22.
//

import SwiftUI

struct DoorLock: View {
    @ObservedObject var viewModel: EniroViewModel

    let lockDoorButton = ServiceButton(buttonTitle: "Lås dörrarna", imageName: "lock.fill")
    let unlockDoorButton = ServiceButton(buttonTitle: "Lås upp dörrarna", imageName: "lock.open.fill")

    var body: some View {
        Button {
            viewModel.lock()
        } label: {
            HassCircleButtonLabelOld(dashboardButton: AnyView(lockDoorButton))
        }

        Button {
            viewModel.unlock()
        } label: {
            HassCircleButtonLabelOld(dashboardButton: AnyView(unlockDoorButton))
        }
    }
}
