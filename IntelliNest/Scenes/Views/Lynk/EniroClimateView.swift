//
//  EniroClimate.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-20.
//

import SwiftUI

struct EniroClimateView: View {
    @ObservedObject var viewModel: LynkViewModel

    var body: some View {
        let climateButtonImageSize: CGFloat = 30

        VStack {
            HStack {
                VStack {
                    ServiceButtonView(buttonTitle: "Starta",
                                      isActive: viewModel.isAirConditionActive,
                                      activeColor: viewModel.climateIconColor,
                                      icon: .init(systemImageName: .thermometer),
                                      iconWidth: 25,
                                      iconHeight: 35,
                                      isLoading: false,
                                      action: viewModel.toggleClimate)

                    /*NavigationButtonView(buttonTitle: "Schemalägg start",
                                          image: Image(systemName: "calendar"),
                                          buttonImageWidth: climateButtonImageSize,
                                          buttonImageHeight: climateButtonImageSize,
                                          frameSize: 80,
                                          action: viewModel.showClimateSchedulingAction)
                     */
                }
                .padding(.trailing)
            }
        }
    }
}
