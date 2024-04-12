//
//  DetailedHeaterView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

enum HeaterType {
    case corridor
    case playroom
}

@MainActor
struct DetailedHeaterView: View {
    @ObservedObject var viewModel: HeatersViewModel
    var selectedHeater: HeaterType

    var heater: HeaterEntity {
        selectedHeater == .corridor ? viewModel.heaterCorridor : viewModel.heaterPlayroom
    }

    var body: some View {
        VStack {
            Text("Fläkt")
                .font(.title2)
                .foregroundColor(.white)
            FanModeView(fanMode: heater.fanMode,
                        fanModeSelectedCallback: { fanMode in
                            viewModel.setFanMode(heater, fanMode)
                        })
                        .padding(.bottom)

            Text("Horisontellt läge")
                .font(.title2)
                .foregroundColor(.white)
            HorizontalModeView(mode: heater.vaneHorizontal,
                               leftVaneTitle: heater.leftVaneTitle,
                               rightVaneTitle: heater.rightVaneTitle,
                               horizontalModeSelectedCallback: { horizontalMode in
                                   viewModel.horizontalModeSelectedCallback(heater, horizontalMode)
                               })
                               .padding(.bottom)

            Text("Vertikalt läge")
                .font(.title2)
                .foregroundColor(.white)
            VerticalPositionView(mode: heater.vaneVertical,
                                 verticalModeSelectedCallback: { verticalMode in
                                     viewModel.verticalModeSelectedCallback(heater, verticalMode)
                                 })
            Spacer()
        }
        .padding()
        .backgroundModifier()
    }
}

struct DetailedHeaterView_Previews: PreviewProvider {
    static var previews: some View {
        DetailedHeaterView(viewModel: PreviewProviderUtil.heatersViewModel, selectedHeater: .corridor)
    }
}
