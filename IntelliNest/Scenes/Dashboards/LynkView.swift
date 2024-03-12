//
//  LynkView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-03.
//

import SwiftUI

struct LynkView: View {
    @ObservedObject var viewModel: LynkViewModel

    var body: some View {
        ZStack {
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
                        ServiceButtonView(buttonTitle: "Ladda ner från bil",
                                          icon: .init(systemImageName: .arrowDown),
                                          imageSize: 20,
                                          isLoading: false,
                                          action: viewModel.update)
                        ServiceButtonView(buttonTitle: "Starta laddning",
                                          icon: .init(systemImageName: .boltCar),
                                          imageSize: 20,
                                          action: viewModel.startCharging)
                        ServiceButtonView(buttonTitle: "Pausa laddning",
                                          icon: .init(systemImageName: .xmarkCircle),
                                          imageSize: 20,
                                          action: viewModel.stopCharging)
                    }

                    HStack {
                        ServiceButtonView(buttonTitle: "Lås dörrarna",
                                          icon: .init(systemImageName: .locked),
                                          iconHeight: 25,
                                          action: viewModel.lock)
                        ServiceButtonView(buttonTitle: "Lås upp dörrarna",
                                          icon: .init(systemImageName: .unlocked),
                                          imageSize: 25,
                                          action: viewModel.unlock)
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
        }
    }
}

struct Eniro_Previews: PreviewProvider {
    static var previews: some View {
        LynkView(viewModel: LynkViewModel(restAPIService: PreviewProviderUtil.restAPIService,
                                          showClimateSchedulingAction: {}))
    }
}
