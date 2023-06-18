//
//  EniroUpdaters.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-22.
//

import SwiftUI

struct EniroUpdaters: View {
    @ObservedObject var viewModel: EniroViewModel
    @Binding var updateIsLoading: Bool
    var forceUpdateIsLoading: Bool
    var lastUpdated: String

    var body: some View {
        let updateButton = ServiceButton(buttonTitle: "Ladda ner från bil",
                                         imageName: "arrow.down",
                                         isLoading: updateIsLoading)
        let forceUpdateButton = ServiceButton(buttonTitle: "Ladda upp från bil",
                                              imageName: "arrow.up",
                                              isLoading: forceUpdateIsLoading)

        HStack {
            Button {
                viewModel.updateTask()
            } label: {
                HassCircleButtonLabelOld(dashboardButton: AnyView(updateButton))
            }.disabled(updateIsLoading)

            Button {
                viewModel.initiateForceUpdate()
            } label: {
                HassCircleButtonLabelOld(dashboardButton: AnyView(forceUpdateButton))
            }.disabled(forceUpdateIsLoading)
        }
    }
}
