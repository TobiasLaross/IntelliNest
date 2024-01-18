//
//  ElectricityFlowView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-12-20.
//

import SwiftUI

private struct PowerView: View {
    var text: String
    var imageName: ImageName?
    var imageSystemName: SystemImageName?
    var batteryView: BatteryView?

    var body: some View {
        Group {
            if let imageName {
                Image(imageName: imageName)
            } else if let imageSystemName {
                Image(systemImageName: imageSystemName)
                    .resizable()
                    .frame(width: 36, height: 36)
            } else if let batteryView {
                batteryView
            }
        }
        .overlay(alignment: .top) {
            Text(text)
                .font(.circleButtonFontSmall)
                .frame(width: 70)
                .lineLimit(1)
                .offset(y: -14)
        }
        .padding(.top, 8)
    }
}

struct ElectricityFlowView: View {
    var hasFlowBatteryToGrid: Binding<Bool> {
        Binding(
            get: { viewModel.sonnenBattery.hasFlowBatteryToGrid },
            set: { _ in }
        )
    }

    @ObservedObject var viewModel: ElectricityViewModel

    var body: some View {
        HStack {
            PowerView(text: viewModel.pulsePower.state.toKW, imageName: .powerGrid)
                .overlay(alignment: .trailing) {
                    FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowGridToHouse,
                                      flowIntensity: 0.5, arrowCount: 6)
                        .offset(x: 140)
                }
                .overlay(alignment: .bottomTrailing) {
                    FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowGridToBattery, flowIntensity: 0.5, arrowCount: 3)
                        .rotationEffect(.degrees(45))
                        .offset(x: 50)
                }
            Spacer()
                .frame(width: 50)
            VStack {
                PowerView(text: viewModel.sonnenBattery.solarProduction.toKW, imageName: .solarPanel)
                    .overlay(alignment: .bottomLeading) {
                        FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowSolarToGrid,
                                          flowIntensity: 0.5,
                                          arrowCount: 2)
                            .rotationEffect(.degrees(135))
                            .offset(x: -20, y: 20)
                    }
                    .overlay(alignment: .bottom) {
                        FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowSolarToBattery,
                                          flowIntensity: 0.5, arrowCount: 2)
                            .rotationEffect(.degrees(90))
                            .offset(y: 30)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowSolarToHouse,
                                          flowIntensity: 0.5, arrowCount: 3)
                            .rotationEffect(.degrees(45))
                            .offset(x: 50, y: 30)
                    }

                Spacer()
                    .frame(height: 65)
                PowerView(text: viewModel.sonnenBattery.batteryPower.toKW,
                          batteryView: BatteryView(level: viewModel.sonnenBattery.chargedPercent,
                                                   isCharging: viewModel.sonnenBattery.batteryPower > 100,
                                                   width: 45,
                                                   height: 80))
                    .onTapGesture {
                        viewModel.isShowingSonnenSettings = true
                    }
                    .overlay(alignment: .leading) {
                        FlowIndicatorView(isFlowing: hasFlowBatteryToGrid,
                                          flowIntensity: 0.5,
                                          arrowCount: 3)
                            .rotationEffect(.degrees(225))
                            .offset(x: -60, y: -20)
                    }
                    .overlay(alignment: .trailing) {
                        FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowBatteryToHouse,
                                          flowIntensity: 0.5,
                                          arrowCount: 3)
                            .rotationEffect(.degrees(-45))
                            .offset(x: 60, y: -20)
                    }
            }

            Spacer()
                .frame(width: 50)
            PowerView(text: viewModel.sonnenBattery.houseConsumption.toKW, imageSystemName: .house)
            Spacer()
        }
    }
}

#Preview {
    ElectricityFlowView(viewModel: .init(sonnenBattery: .init(entityID: .sonnenBattery),
                                         websocketService: .init()))
}

#Preview {
    PowerView(text: "22.3kW", imageName: .solarPanel)
        .overlay(alignment: .bottomTrailing) {
            FlowIndicatorView(isFlowing: .constant(true), flowIntensity: 0.5, arrowCount: 3)
                .rotationEffect(.degrees(45))
                .offset(x: 25)
        }
}
