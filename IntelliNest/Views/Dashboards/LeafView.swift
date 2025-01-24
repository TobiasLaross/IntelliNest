import SwiftUI

struct LeafView: View {
    @ObservedObject var viewModel: LeafViewModel
    @State var isEngineAlertVisible = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack {
                    BatteryView(level: Int(viewModel.battery.inputNumber.rounded()),
                                isCharging: viewModel.isCharging.isActive,
                                degreeRotation: 90,
                                width: 50,
                                height: 90)
                    Text("\(viewModel.rangeAC.state)km (\(viewModel.range.state)km utan AC)")
                        .font(.buttonFontSmall)
                        .foregroundColor(.white)
                        .padding(.top, -32)
                    Text("\(viewModel.range.state)km")
                        .font(.buttonFontSmall)
                        .foregroundColor(.white)
                        .padding(.top, -25)
                    if viewModel.isCharging.isActive {
                        Text("charging info...")
                            .font(.buttonFontExtraSmall)
                            .foregroundColor(.white)
                            .padding(.top, -20)
                    }
                }
                .padding(.trailing, 16)

                ServiceButtonView(buttonTitle: viewModel.climateTitle,
                                  isActive: viewModel.isAirConditionActive,
                                  activeColor: viewModel.climateIconColor,
                                  buttonSize: 90,
                                  icon: .init(systemImageName: .thermometer),
                                  iconWidth: 25,
                                  iconHeight: 35,
                                  isLoading: viewModel.isAirConditionLoading,
                                  action: viewModel.toggleClimate)
                Spacer()
            }
            Spacer()
        }
    }
}

/* struct Leaf_Previews: PreviewProvider {
     static var previews: some View {
         LeafView(viewModel: PreviewProviderUtil.lynkViewModel)
             .backgroundModifier()
     }
 }
 */
