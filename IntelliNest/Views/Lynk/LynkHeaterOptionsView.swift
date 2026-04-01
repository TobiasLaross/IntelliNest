import SwiftUI

struct LynkHeaterOptionsView: View {
    @ObservedObject var viewModel: LynkViewModel
    let buttonWidth = 80.0
    let buttonHeight = 50.0

    var body: some View {
        ZStack {
            FullScreenBackgroundOverlay()
                .onTapGesture {
                    viewModel.isShowingHeaterOptions = false
                }
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primaryContentBackground)
                .frame(width: 300, height: 130)
                .overlay {
                    ZStack {
                        VStack {
                            INText("Lynk \(viewModel.lynkChargerConnectionDescription)",
                                   font: .body)
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                            HStack {
                                ServiceButtonView(buttonTitle: "Starta Klimatet",
                                                  isActive: viewModel.isLynkAirConditionActive,
                                                  buttonWidth: buttonWidth,
                                                  buttonHeight: buttonHeight,
                                                  cornerRadius: 20,
                                                  isLoading: viewModel.isLynkAirConditionLoading,
                                                  action: viewModel.startLynkClimate)
                                    .disabled(viewModel.isLynkAirConditionLoading)
                                ServiceButtonView(buttonTitle: "Starta Motorn",
                                                  isActive: viewModel.isEngineRunning.isActive,
                                                  buttonWidth: buttonWidth,
                                                  buttonHeight: buttonHeight,
                                                  cornerRadius: 20,
                                                  isLoading: viewModel.isEngineLoading,
                                                  action: viewModel.startEngine)
                                    .disabled(viewModel.isEngineLoading)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
        }
    }
}

#Preview {
    LynkHeaterOptionsView(viewModel: PreviewProviderUtil.lynkViewModel)
}
