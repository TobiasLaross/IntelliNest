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
                    Group {
                        Text("Kostnad idag: ") + Text("\(viewModel.tibberCostToday.state.toKr)").bold() +
                            Text("\nKöpt idag: ") + Text("\(viewModel.pulseConsumptionToday.state.toKWh)").bold() +
                            Text("\nMode: ") + Text("\(viewModel.sonnenBattery.operationMode.title)").bold()
                    }
                    .font(.buttonFontMedium)
                    .lineLimit(3)
                    .minimumScaleFactor(0.1)
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
    VStack {
        ElectricityView(viewModel: .init(sonnenBattery: .init(entityID: .sonnenBattery),
                                         websocketService: PreviewProviderUtil.websocketService))
            .backgroundModifier()
    }
}
