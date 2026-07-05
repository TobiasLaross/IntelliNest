//
//  HeatersView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-02.
//

import SwiftUI

struct HeatersView: View {
    @ObservedObject var viewModel: HeatersViewModel

    var body: some View {
        ScrollView {
            VStack {
                SimpleHeaterView(roomName: "Korridoren",
                                 therm1: viewModel.thermCorridor,
                                 therm2: viewModel.thermBedroom,
                                 therm3: viewModel.thermVince,
                                 therm4: viewModel.thermGym,
                                 heater: $viewModel.heaterCorridor,
                                 resetClimateTimeEntity: $viewModel.resetCorridorHeaterTime,
                                 isTimerModeEnabled: viewModel.heaterCorridorTimerMode.isActive,
                                 showDetailsClosure: viewModel.showHeaterDetails,
                                 setTargetTemperatureClosure: viewModel.setTargetTemperature,
                                 setHvacModeClosure: viewModel.setHvacMode,
                                 toggleTimerModeClosure: viewModel.toggleCorridorTimerMode,
                                 setClimateScheduleTimeClosure: viewModel.setClimateSchedule)
                    .padding(.top)
                Divider()
                SimpleHeaterView(roomName: "Lekrummet",
                                 therm1: viewModel.thermPlayroom,
                                 therm2: viewModel.thermCommonarea,
                                 therm3: viewModel.thermGuest,
                                 therm4: viewModel.thermKitchen,
                                 heater: $viewModel.heaterPlayroom,
                                 resetClimateTimeEntity: $viewModel.resetPlayroomHeaterTime,
                                 isTimerModeEnabled: viewModel.heaterPlayroomTimerMode.isActive,
                                 showDetailsClosure: viewModel.showHeaterDetails,
                                 setTargetTemperatureClosure: viewModel.setTargetTemperature,
                                 setHvacModeClosure: viewModel.setHvacMode,
                                 toggleTimerModeClosure: viewModel.togglePlayroomTimerMode,
                                 setClimateScheduleTimeClosure: viewModel.setClimateSchedule)
                    .padding(.bottom)
                Divider()
                PurifierView(title: "Luftrenare",
                             subtitle: viewModel.purifierSubtitle,
                             fanEntityId: .purifierFanSpeed,
                             maxLevel: PurifierFanScale.pure.levelCount,
                             currentLevel: viewModel.purifier.speed,
                             resetClimateTimeEntity: $viewModel.resetPurifierTime,
                             isTimerModeEnabled: viewModel.purifierTimerMode.isActive,
                             setFanSpeedClosure: viewModel.setPurifierFanSpeed,
                             toggleTimerModeClosure: viewModel.togglePurifierTimerMode,
                             setClimateScheduleTimeClosure: viewModel.setClimateSchedule)
                    .padding(.bottom)
                Divider()
                PurifierView(title: "Luftrenare 500",
                             subtitle: viewModel.purifier500Subtitle,
                             fanEntityId: .purifier500FanSpeed,
                             maxLevel: PurifierFanScale.pure500.levelCount,
                             currentLevel: viewModel.purifier500.speed,
                             resetClimateTimeEntity: $viewModel.resetPurifier500Time,
                             isTimerModeEnabled: viewModel.purifier500TimerMode.isActive,
                             setFanSpeedClosure: viewModel.setPurifier500FanSpeed,
                             toggleTimerModeClosure: viewModel.togglePurifier500TimerMode,
                             setClimateScheduleTimeClosure: viewModel.setClimateSchedule)
                    .padding(.bottom)
            }
        }
    }
}

struct HeatersView_Previews: PreviewProvider {
    static var previews: some View {
        HeatersView(viewModel: HeatersViewModel(restAPIService: PreviewProviderUtil.restAPIService,
                                                showHeaterDetails: { _ in }))
    }
}
