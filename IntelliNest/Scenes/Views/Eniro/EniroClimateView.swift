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
        let heatingImageSize: CGFloat = 20
        let frameSize: CGFloat = 80
        let heatingButtonframeSize: CGFloat = 45
        let climateHeatingButton = SwitchButton(entity: $viewModel.climateHeating, buttonTitle: "",
                                                activeImageName: "seatheater.filled", defaultImageName: "seatheater.filled",
                                                isSystemName: false, buttonImageSize: heatingImageSize)
        let climateDefrostButton = SwitchButton(entity: $viewModel.climateDefrost, buttonTitle: "",
                                                activeImageName: "defrost.filled", defaultImageName: "defrost.filled",
                                                isSystemName: false, buttonImageSize: heatingImageSize)

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
                        Button {
                            viewModel.toggleState(for: viewModel.climateHeating)
                        } label: {
                            HassButtonLabel(button: AnyView(climateHeatingButton),
                                            buttonFrameHeight: heatingButtonframeSize,
                                            buttonFrameWidth: heatingButtonframeSize)
                        }

                        Button {
                            viewModel.toggleState(for: viewModel.climateDefrost)
                        } label: {
                            HassButtonLabel(button: AnyView(climateDefrostButton),
                                            buttonFrameHeight: heatingButtonframeSize,
                                            buttonFrameWidth: heatingButtonframeSize)
                        }
                    }
                }

                VStack {
                    DashboardButtonView(text: "Starta",
                                        isActive: viewModel.isAirConditionActive,
                                        icon: Image(systemName: "thermometer"),
                                        iconWidth: 22,
                                        iconHeight: 35,
                                        iconForegroundColor: viewModel.climateIconColor,
                                        isLoading: false,
                                        isCircle: true,
                                        action: viewModel.startClimate)
                    NavigationLink(value: Destination.eniroClimateSchedule,
                                   label: { HassButtonLabel(button: AnyView(climateScheduleButton),
                                                            buttonFrameHeight: frameSize,
                                                            buttonFrameWidth: frameSize) })
                }
                .padding(.trailing)
            }
        }
    }
}
