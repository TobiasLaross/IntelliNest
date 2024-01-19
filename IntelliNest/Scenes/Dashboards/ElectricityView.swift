//
//  ElectricityView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-12-15.
//

import SwiftUI

struct ElectricityView: View {
    @ObservedObject var viewModel: ElectricityViewModel

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    ElectricityFlowView(viewModel: viewModel)
                        .frame(width: 230)
                        .padding([.top, .leading], 16)
                    Text("""
                    Kostnad idag: ***\(viewModel.tibberCostToday.state.toKr)***
                    Köpt idag: ***\(viewModel.pulseConsumptionToday.state.toKWh)***
                    Mode: ***\(viewModel.sonnenBattery.operationMode.title)***
                    """)
                    .font(.circleButtonFontMedium)
                    .padding(.top, 8)
                    Spacer()
                }
                Spacer()
                NordPoolHistoryView(nordPool: viewModel.nordPool)
                    .frame(height: 350)
                    .padding(.bottom, 16)
                    .padding(.horizontal, 8)
            }

            if viewModel.isShowingSonnenSettings {
                SonnenSettingsView(viewModel: viewModel)
            }
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    ZStack {
        FullScreenBackgroundOverlay()
        VStack {
            ElectricityView(viewModel: .init(sonnenBattery: .init(entityID: .sonnenBattery),
                                             websocketService: .init(reloadConnectionAction: {})))
        }
    }
}
