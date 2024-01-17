//
//  Airconditions.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-02.
//

import SwiftUI

struct HeatersView: View {
    @ObservedObject var viewModel: HeatersViewModel

    var body: some View {
        VStack {
            SimpleHeaterView(roomName: "Korridoren",
                             therm1: viewModel.thermCorridor,
                             therm2: viewModel.thermBedroom,
                             therm3: viewModel.thermVince,
                             therm4: viewModel.thermGym,
                             heater: $viewModel.heaterCorridor,
                             showDetails: $viewModel.showCorridorDetails,
                             resetClimateTimeEntity: $viewModel.resetCorridorHeaterTime,
                             isTimerModeEnabled: viewModel.heaterCorridorTimerMode.isActive,
                             setTargetTemperatureClosure: viewModel.setTargetTemperature,
                             setHvacModeClosure: viewModel.setHvacMode,
                             toggleTimerModeAction: viewModel.toggleCorridorTimerMode,
                             setClimateScheduleTime: viewModel.setClimateSchedule)
                .padding(.top)
            Divider()
            SimpleHeaterView(roomName: "Lekrummet",
                             therm1: viewModel.thermPlayroom,
                             therm2: viewModel.thermCommonarea,
                             therm3: viewModel.thermGuest,
                             therm4: viewModel.thermKitchen,
                             heater: $viewModel.heaterPlayroom,
                             showDetails: $viewModel.showPlayroomDetails,
                             resetClimateTimeEntity: $viewModel.resetPlayroomHeaterTime,
                             isTimerModeEnabled: viewModel.heaterPlayroomTimerMode.isActive,
                             setTargetTemperatureClosure: viewModel.setTargetTemperature,
                             setHvacModeClosure: viewModel.setHvacMode,
                             toggleTimerModeAction: viewModel.togglePlayroomTimerMode,
                             setClimateScheduleTime: viewModel.setClimateSchedule)
                .padding(.bottom)
            Spacer()
                .popover(isPresented: $viewModel.showCorridorDetails, arrowEdge: .top) {
                    DetailedHeaterView(heater: viewModel.heaterCorridor,
                                       fanMode: viewModel.heaterCorridor.fanMode,
                                       horizontalMode: viewModel.heaterCorridor.vaneHorizontal,
                                       verticalMode: viewModel.heaterCorridor.vaneVertical,
                                       fanModeSelectedCallback: viewModel.fanModeSelectedCallback,
                                       horizontalModeSelectedCallback: viewModel.horizontalModeSelectedCallback,
                                       verticalModeSelectedCallback: viewModel.verticalModeSelectedCallback)
                }

                .popover(isPresented: $viewModel.showPlayroomDetails, arrowEdge: .top) {
                    DetailedHeaterView(heater: viewModel.heaterPlayroom,
                                       fanMode: viewModel.heaterPlayroom.fanMode,
                                       horizontalMode: viewModel.heaterPlayroom.vaneHorizontal,
                                       verticalMode: viewModel.heaterPlayroom.vaneVertical,
                                       fanModeSelectedCallback: viewModel.fanModeSelectedCallback,
                                       horizontalModeSelectedCallback: viewModel.horizontalModeSelectedCallback,
                                       verticalModeSelectedCallback: viewModel.verticalModeSelectedCallback)
                }
        }
    }
}

struct HeatersView_Previews: PreviewProvider {
    static var previews: some View {
        HeatersView(viewModel: HeatersViewModel(websocketService: .init(), apiService: HassApiService(urlCreator: URLCreator())))
    }
}
