//
//  Eniro.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-03.
//

import SwiftUI

struct EniroView: View {
    @ObservedObject var viewModel: EniroViewModel

    var body: some View {
        ZStack {
            Rectangle().background(topGrayColor).foregroundColor(bodyColor).edgesIgnoringSafeArea(.bottom)
            VStack {
                VStack {
                    Text("Klimathantering")
                        .font(.headline)
                        .foregroundColor(.white)
                    EniroClimateView(viewModel: viewModel)
                }
                .padding()

                Divider()

                VStack {
                    HStack {
                        CircleButtonView(buttonTitle: "Ladda ner från bil",
                                         icon: .init(systemImageName: .arrowDown),
                                         imageSize: 20,
                                         isLoading: viewModel.updateIsloading,
                                         action: viewModel.update)
                            .disabled(viewModel.updateIsloading)
                        CircleButtonView(buttonTitle: "Ladda upp från bil",
                                         icon: .init(systemImageName: .arrowUp),
                                         imageSize: 20,
                                         action: viewModel.initiateForceUpdate)

                        CircleButtonView(buttonTitle: "Starta laddning",
                                         icon: .init(systemImageName: .boltCar),
                                         imageSize: 20,
                                         action: viewModel.startCharging)
                        CircleButtonView(buttonTitle: "Avbryt laddning",
                                         icon: .init(systemImageName: .xmarkCircle),
                                         imageSize: 20,
                                         action: viewModel.stopCharging)
                    }

                    HStack {
                        CircleButtonView(buttonTitle: "Lås dörrarna",
                                         icon: .init(systemImageName: .locked),
                                         iconHeight: 25,
                                         action: viewModel.lock)
                        CircleButtonView(buttonTitle: "Lås upp dörrarna",
                                         icon: .init(systemImageName: .unlocked),
                                         imageSize: 25,
                                         action: viewModel.unlock)
                        CircleButtonView(buttonTitle: "\(viewModel.eniroChargingACLimit.state)%",
                                         icon: .init(imageName: .evPlugType2),
                                         imageSize: 35,
                                         action: viewModel.showACLimitPicker)
                        CircleButtonView(buttonTitle: "\(viewModel.eniroChargingACLimit.state)%",
                                         icon: .init(imageName: .evPlugCCS2),
                                         imageSize: 35,
                                         action: viewModel.showDCLimitPicker)
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.top)
                EniroInfoView(viewModel: viewModel)
                    .padding(.horizontal)
                Spacer()
                Text("Senast uppdaterad: \(viewModel.lastUpdated)")
                    .font(Font.system(size: 12).italic())
                    .foregroundColor(.white)
                    .padding(.bottom)
            }
            if let limitPickerEntity = viewModel.limitPickerEntity {
                LimitPickerView(limitEntity: limitPickerEntity,
                                saveChargerLimit: viewModel.saveChargerLimit,
                                currentLimit: limitPickerEntity.inputNumber)
            }
        }
        .onAppear {
            viewModel.appearedAction(.eniro)
        }
    }
}

struct Eniro_Previews: PreviewProvider {
    static var previews: some View {
        EniroView(viewModel: EniroViewModel(websocketService: WebSocketService(), appearedAction: { _ in }))
    }
}
