import SwiftUI

struct LynkHeaterOptionsView: View {
    @ObservedObject var viewModel: LynkViewModel

    var body: some View {
        ZStack {
            FullScreenBackgroundOverlay()
                .onTapGesture {
                    viewModel.isShowingHeaterOptions = false
                }
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primaryContentBackground)
                .frame(width: 300, height: 200)
                .overlay {
                    ZStack {
                        VStack {
                            INText("Lynk är \(viewModel.lynkChargerConnectionStatus.state) och \(viewModel.lynkChargerState.state)",
                                   font: .buttonFontLarge)
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                            HStack {
                                ServiceButtonView(buttonTitle: "Starta Klimatet",
                                                  isActive: viewModel.isLynkAirConditionActive,
                                                  buttonWidth: viewModel.buttonSize,
                                                  buttonHeight: 90,
                                                  cornerRadius: 20,
                                                  isLoading: viewModel.isLynkAirConditionLoading,
                                                  action: viewModel.startLynkClimate)
                                    .disabled(viewModel.isLynkAirConditionLoading)
                                ServiceButtonView(buttonTitle: "Starta Motorn",
                                                  isActive: viewModel.isEngineRunning.isActive,
                                                  buttonWidth: viewModel.buttonSize,
                                                  buttonHeight: 90,
                                                  cornerRadius: 20,
                                                  isLoading: viewModel.isEngineLoading,
                                                  action: viewModel.startEngine)
                                    .disabled(viewModel.isEngineLoading)
                            }
                            INText("Leaf", font: .buttonFontLarge)
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                            HStack {
                                ServiceButtonView(buttonTitle: "Starta Klimatet",
                                                  isActive: viewModel.isLeafAirConditionActive,
                                                  buttonWidth: 90,
                                                  buttonHeight: 60,
                                                  cornerRadius: 20,
                                                  isLoading: viewModel.isLeafAirConditionLoading,
                                                  action: viewModel.startLeafClimate)
                                    .disabled(viewModel.isLynkAirConditionLoading)
                            }
                        }
                    }
                }
        }
    }
}

#Preview {
    LynkHeaterOptionsView(viewModel: PreviewProviderUtil.lynkViewModel)
}
