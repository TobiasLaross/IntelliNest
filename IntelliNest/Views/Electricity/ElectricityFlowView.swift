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
                .font(.buttonFontSmall)
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
            PowerView(text: viewModel.gridPower, imageName: .powerGrid)
                .overlay(alignment: .trailing) {
                    FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowGridToHouse,
                                      flowIntensity: abs(viewModel.sonnenBattery.gridPower.toKW) > 3 ? 3.0 : 1.0,
                                      arrowCount: 6)
                        .offset(x: 140)
                }
                .overlay(alignment: .bottomTrailing) {
                    FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowGridToBattery,
                                      flowIntensity: abs(viewModel.sonnenBattery.gridPower.toKW) > 3 ? 3.0 : 1.0,
                                      arrowCount: 3)
                        .rotationEffect(.degrees(45))
                        .offset(x: 50)
                }
            Spacer()
                .frame(width: 50)
            VStack {
                PowerView(text: viewModel.sonnenBattery.solarProduction.toKWString, imageName: .solarPanel)
                    .overlay(alignment: .bottomLeading) {
                        FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowSolarToGrid,
                                          flowIntensity: abs(viewModel.sonnenBattery.solarProduction.toKW) >= 3 ? 2.0 : 1.0,
                                          arrowCount: 4)
                            .rotationEffect(.degrees(145))
                            .offset(x: -50, y: 30)
                    }
                    .overlay(alignment: .bottom) {
                        FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowSolarToBattery,
                                          flowIntensity: abs(viewModel.sonnenBattery.solarProduction.toKW) >= 3 ? 2.0 : 1.0,
                                          arrowCount: 2)
                            .rotationEffect(.degrees(90))
                            .offset(y: 30)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowSolarToHouse,
                                          flowIntensity: abs(viewModel.sonnenBattery.solarProduction.toKW) >= 3 ? 2.0 : 1.0,
                                          arrowCount: 3)
                            .rotationEffect(.degrees(45))
                            .offset(x: 50, y: 30)
                    }

                Spacer()
                    .frame(height: 65)
                PowerView(text: viewModel.sonnenBattery.batteryPower.toKWString,
                          batteryView: BatteryView(level: viewModel.sonnenBattery.chargedPercent,
                                                   isCharging: viewModel.sonnenBattery.batteryPower > 100,
                                                   width: 45,
                                                   height: 80))
                    .onTapGesture {
                        viewModel.isShowingSonnenSettings = true
                    }
                    .overlay(alignment: .leading) {
                        FlowIndicatorView(isFlowing: hasFlowBatteryToGrid,
                                          flowIntensity: abs(viewModel.sonnenBattery.batteryPower.toKW) > 3 ? 3.0 : 1.5,
                                          arrowCount: 3)
                            .rotationEffect(.degrees(225))
                            .offset(x: -60, y: -20)
                    }
                    .overlay(alignment: .trailing) {
                        FlowIndicatorView(isFlowing: $viewModel.sonnenBattery.hasFlowBatteryToHouse,
                                          flowIntensity: abs(viewModel.sonnenBattery.batteryPower.toKW) > 3 ? 3.0 : 1.5,
                                          arrowCount: 3)
                            .rotationEffect(.degrees(-45))
                            .offset(x: 60, y: -20)
                    }
            }

            Spacer()
                .frame(width: 50)
            PowerView(text: viewModel.sonnenBattery.houseConsumption.toKWString, imageSystemName: .house)
            Spacer()
        }
    }
}

#Preview {
    ElectricityFlowView(viewModel: PreviewProviderUtil.electricityViewModel)
}

#Preview {
    PowerView(text: "22.3kW", imageName: .solarPanel)
        .overlay(alignment: .bottomTrailing) {
            FlowIndicatorView(isFlowing: .constant(true), flowIntensity: 0.5, arrowCount: 3)
                .rotationEffect(.degrees(45))
                .offset(x: 25)
        }
}
