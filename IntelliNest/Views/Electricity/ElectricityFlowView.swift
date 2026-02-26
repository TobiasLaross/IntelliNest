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
    @ObservedObject var viewModel: ElectricityViewModel

    var body: some View {
        VStack(alignment: .center) {
            PowerView(text: viewModel.solarPower.toKWString, imageName: .solarPanel)
                .overlay(alignment: .bottomLeading) {
                    FlowIndicatorView(isFlowing: viewModel.isSolarToGrid,
                                      flowIntensity: abs(viewModel.solarPower.toKW) >= 3 ? 2.0 : 1.0,
                                      arrowCount: 4)
                        .rotationEffect(.degrees(120))
                        .offset(x: -50, y: 35)
                }
                .overlay(alignment: .bottomTrailing) {
                    FlowIndicatorView(isFlowing: viewModel.isSolarToHouse,
                                      flowIntensity: abs(viewModel.solarPower.toKW) >= 3 ? 2.0 : 1.0,
                                      arrowCount: 4)
                        .rotationEffect(.degrees(70))
                        .offset(x: 40, y: 35)
                }
            HStack {
                PowerView(text: viewModel.gridPower.toKWString, imageName: .powerGrid)
                    .overlay(alignment: .bottomLeading) {
                        FlowIndicatorView(isFlowing: viewModel.isGridToHouse,
                                          flowIntensity: abs(viewModel.gridPower.toKW) >= 3 ? 2.0 : 1.0,
                                          arrowCount: 4)
                            .offset(x: 50, y: -20)
                    }
                    .padding(.trailing, 80)
                PowerView(text: viewModel.housePower.toKWString, imageSystemName: .house)
            }
            .padding(.top, 65)
        }
    }
}

#Preview {
    ElectricityFlowView(viewModel: PreviewProviderUtil.electricityViewModel)
}

#Preview {
    PowerView(text: "22.3kW", imageName: .solarPanel)
        .overlay(alignment: .bottomTrailing) {
            FlowIndicatorView(isFlowing: true, flowIntensity: 0.5, arrowCount: 3)
                .rotationEffect(.degrees(45))
                .offset(x: 25)
        }
}
