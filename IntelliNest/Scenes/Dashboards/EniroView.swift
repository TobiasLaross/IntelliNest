//
//  Eniro.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-03.
//

import SwiftUI

struct EniroView: View {
    @ObservedObject private var viewModel: EniroViewModel

    init(viewModel: EniroViewModel) {
        self.viewModel = viewModel
    }

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
                        EniroUpdaters(viewModel: viewModel,
                                      updateIsLoading: $viewModel.updateIsloading,
                                      forceUpdateIsLoading: viewModel.forceUpdateIsLoading,
                                      lastUpdated: viewModel.eniroLastUpdate.state)
                        Charging(viewModel: viewModel)
                    }

                    HStack {
                        DoorLock(viewModel: viewModel)
                        EniroChargingLimitView(viewModel: viewModel)
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.top)
                EniroInfoView(viewModel: viewModel)
                    .padding(.horizontal)
                Spacer()
                Text("Senast uppdaterad: \(viewModel.lastUpdated())")
                    .font(Font.system(size: 12).italic())
                    .foregroundColor(.white)
                    .padding(.bottom)
            }
            if viewModel.nordPoolHistoryIsVisible {
                NordPoolHistoryView(isVisible: $viewModel.nordPoolHistoryIsVisible,
                                    nordPool: viewModel.nordPool)
            } else if let limitPickerEntity = viewModel.limitPickerEntity {
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
        EniroView(viewModel: EniroViewModel(apiService: HassApiService(urlCreator: URLCreator()), appearedAction: { _ in }))
    }
}
