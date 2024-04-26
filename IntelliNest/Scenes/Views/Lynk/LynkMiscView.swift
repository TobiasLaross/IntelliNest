import SwiftUI

struct LynkMiscView: View {
    @ObservedObject var viewModel: LynkViewModel
    @State private var isShowingAlert = false

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                ServiceButtonView(buttonTitle: viewModel.doorLockTitle,
                                  isActive: viewModel.isLynkUnlocked,
                                  buttonSize: 90,
                                  icon: viewModel.doorLockIcon,
                                  iconWidth: viewModel.isLynkUnlocked ? 30 : 20,
                                  iconHeight: 30,
                                  isLoading: viewModel.lynkDoorLock.isLoading,
                                  action: viewModel.toggleDoorLock)
                    .disabled(viewModel.lynkDoorLock.isLoading)
                    .contextMenu {
                        Button(action: viewModel.lockDoors, label: {
                            Text("Lås")
                        })
                        Button(action: viewModel.unlockDoors, label: {
                            Text("Lås upp")
                        })
                    }

                ServiceButtonView(buttonTitle: viewModel.flashLightTitle,
                                  isActive: viewModel.isLynkFlashing,
                                  buttonSize: 90,
                                  icon: viewModel.flashLightIcon,
                                  iconWidth: 30,
                                  iconHeight: 30,
                                  action: {
                                      if !viewModel.isLynkFlashing {
                                          isShowingAlert = true
                                      } else {
                                          viewModel.stopFlashLights()
                                      }
                                  })
                                  .alert(isPresented: $isShowingAlert) {
                                      Alert(
                                          title: Text("Starta lampor"),
                                          message: Text(""),
                                          primaryButton: .destructive(Text("Ja")) {
                                              viewModel.startFlashLights()
                                          },
                                          secondaryButton: .cancel()
                                      )
                                  }
                                  .disabled(viewModel.lynkDoorLock.isLoading)
                                  .contextMenu {
                                      Button(action: viewModel.startFlashLights, label: {
                                          Text("Starta lamporna")
                                      })
                                      Button(action: viewModel.stopFlashLights, label: {
                                          Text("Stäng av lamporna")
                                      })
                                  }
                ServiceButtonView(buttonTitle: viewModel.chargingTitle,
                                  isActive: viewModel.isEaseeCharging,
                                  buttonSize: 90,
                                  icon: viewModel.chargingIcon,
                                  imageSize: 40,
                                  action: viewModel.toggleEaseeCharging)
            }
        }
    }
}
