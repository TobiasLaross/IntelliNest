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
                            INText("Laddkabeln är \(viewModel.chargerConnetionStatus.state) och \(viewModel.chargerState.state)",
                                   font: .buttonFontLarge)
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                            HStack {
                                ServiceButtonView(buttonTitle: "Starta Klimatet",
                                                  buttonWidth: 90,
                                                  buttonHeight: 60,
                                                  cornerRadius: 20,
                                                  isLoading: viewModel.isAirConditionLoading,
                                                  action: viewModel.startClimate)
                                    .disabled(viewModel.isAirConditionLoading)
                                ServiceButtonView(buttonTitle: "Starta Motorn",
                                                  buttonWidth: 90,
                                                  buttonHeight: 60,
                                                  cornerRadius: 20,
                                                  isLoading: viewModel.isEngineLoading,
                                                  action: viewModel.startEngine)
                                    .disabled(viewModel.isEngineLoading)
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
