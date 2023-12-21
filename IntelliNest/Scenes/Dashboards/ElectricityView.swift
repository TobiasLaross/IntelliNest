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
        VStack {
            HStack(alignment: .top) {
                ElectricityFlowView(viewModel: viewModel)
                    .frame(width: 230)
                    .padding([.top, .leading], 16)
                Text("""
                Huvudsäkringen: ***\(viewModel.pulsePower.state.toKW)***
                Pris: ***\(viewModel.tibberPrice.state.toOre)***
                Köpt idag: ***\(viewModel.pulseConsumptionToday.state.toKWh)***
                """)
                .font(.circleButtonFontMedium)
                .padding(.top, 8)
                Spacer()
            }
            Spacer()
        }
        .onAppear {
            viewModel.appearedAction(.electricity)
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    ZStack {
        FullScreenBackgroundOverlay()
        VStack {
            ElectricityView(viewModel: .init(sonnenBattery: .init(entityID: .sonnenBattery), websocketService: .init(),
                                             appearedAction: { _ in }))
        }
    }
}
