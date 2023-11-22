//
//  EniroClimate.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-20.
//

import SwiftUI

struct EniroClimateView: View {
    @ObservedObject var viewModel: EniroViewModel

    var body: some View {
        let climateButtonImageSize: CGFloat = 30
        let frameSize: CGFloat = 80

        let climateScheduleButton = NavButton(buttonTitle: "Schemalägg start",
                                              image: Image(systemName: "calendar"),
                                              buttonImageWidth: climateButtonImageSize,
                                              buttonImageHeight: climateButtonImageSize)

        VStack {
            HStack {
                VStack {
                    NumberPickerScrollView(entityId: .eniroClimateTemperature, targetTemperature: $viewModel.climateTemperature.inputNumber,
                                           numberSelectedCallback: viewModel.numberSelectedCallback)
                    HStack {
                        CircleButtonView(buttonTitle: "",
                                         isActive: viewModel.climateHeating.isActive,
                                         icon: .init(imageName: .seatHeater),
                                         buttonSize: 65,
                                         imageSize: 30,
                                         action: {
                                             viewModel.toggleState(for: viewModel.climateHeating)
                                         })
                        CircleButtonView(buttonTitle: "",
                                         isActive: viewModel.climateDefrost.isActive,
                                         icon: .init(imageName: .defrost),
                                         buttonSize: 65,
                                         iconWidth: 30,
                                         iconHeight: 35,
                                         action: {
                                             viewModel.toggleState(for: viewModel.climateDefrost)
                                         })
                    }
                }

                VStack {
                    CircleButtonView(buttonTitle: "Starta",
                                     isActive: viewModel.isAirConditionActive,
                                     activeColor: viewModel.climateIconColor,
                                     icon: .init(systemImageName: .thermometer),
                                     iconWidth: 25,
                                     iconHeight: 35,
                                     isLoading: false,
                                     action: viewModel.toggleClimate)

                    NavigationLink(value: Destination.eniroClimateSchedule,
                                   label: {
                                       HassButtonLabel(button: AnyView(climateScheduleButton),
                                                       buttonFrameHeight: frameSize,
                                                       buttonFrameWidth: frameSize)
                                   })
                }
                .padding(.trailing)
            }
        }
    }
}
