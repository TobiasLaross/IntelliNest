import SwiftUI

struct LeafView: View {
    @ObservedObject var viewModel: LynkViewModel
    @State var isEngineAlertVisible = false

    var body: some View {
        VStack {
            INText("Leaf", font: .title3)
            INText(viewModel.leafLastPoll.date.humanReadable, font: .buttonFontExtraSmall)
                .padding(.bottom)
            HStack {
                Spacer()
                VStack {
                    BatteryView(level: Int(viewModel.leafBattery.inputNumber.rounded()),
                                isCharging: viewModel.isLeafCharging.isActive,
                                degreeRotation: 90,
                                width: 50,
                                height: 90)
                    INText("\(viewModel.leafRangeAC.state)km", font: .buttonFontSmall)
                        .padding(.top, -32)
                }
                .padding(.trailing, 32)

                VStack {
                    ServiceButtonView(buttonTitle: viewModel.leafClimateTitle,
                                      isActive: viewModel.isLeafAirConditionActive,
                                      buttonSize: viewModel.buttonSize,
                                      icon: .init(systemImageName: .thermometer),
                                      iconWidth: 25,
                                      iconHeight: 35,
                                      isLoading: viewModel.isLeafAirConditionLoading,
                                      action: viewModel.toggleLeafClimate)
                        .contextMenu {
                            Button(action: viewModel.startLeafClimate) {
                                INText("Starta")
                            }
                            Button(action: viewModel.stopLeafClimate) {
                                INText("Stoppa")
                            }
                        }
                    if let minutes = viewModel.leafClimateTimerRemaining {
                        INText("\(minutes)min")
                    }
                }
                Spacer()
            }
            Spacer()
        }
    }
}

struct Leaf_Previews: PreviewProvider {
    static var previews: some View {
        LeafView(viewModel: PreviewProviderUtil.lynkViewModel)
            .backgroundModifier()
    }
}
