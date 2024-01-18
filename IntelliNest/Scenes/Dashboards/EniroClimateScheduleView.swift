//
//  ClimateSchedule.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-09.
//

import SwiftUI

struct EniroClimateScheduleView: View {
    @ObservedObject var viewModel: EniroClimateScheduleViewModel

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                    .frame(height: 100)
                VStack {
                    Text("Anpassningsbara").font(.title3).padding(.top)
                    DateTimePickerView(title: "Klimat1", displayComponents: .hourAndMinute,
                                       dateTime: $viewModel.climate1,
                                       dateTimeEnabled: $viewModel.climate1Bool,
                                       updateToggle: viewModel.updateToggle,
                                       setDateTimeClosure: viewModel.setClimateSchedule)
                    DateTimePickerView(title: "Klimat2", displayComponents: .hourAndMinute,
                                       dateTime: $viewModel.climate2,
                                       dateTimeEnabled: $viewModel.climate2Bool,
                                       updateToggle: viewModel.updateToggle,
                                       setDateTimeClosure: viewModel.setClimateSchedule)
                    DateTimePickerView(title: "Klimat3", displayComponents: [.date, .hourAndMinute],
                                       dateTime: $viewModel.climate3,
                                       dateTimeEnabled: $viewModel.climate3Bool,
                                       updateToggle: viewModel.updateToggle,
                                       setDateTimeClosure: viewModel.setClimateSchedule)
                }
                .background(Color.topGrayColor)
                .cornerRadius(dashboardButtonCornerRadius)
                .padding()

                VStack {
                    Text("Automatiseringar")
                        .font(.title3)
                        .padding(.top)
                    ClimateAutomationsView(title: "Morgon",
                                           time: viewModel.climateMorning.date,
                                           climateBool: $viewModel.climateMorningBool,
                                           updateToggle: viewModel.updateToggle)
                    ClimateAutomationsView(title: "Axis",
                                           time: viewModel.climateDay.date,
                                           climateBool: $viewModel.climateDayBool,
                                           updateToggle: viewModel.updateToggle)
                }
                .padding()
                Spacer()
            }
        }
    }
}

struct EniroClimateSchedule_Previews: PreviewProvider {
    static var previews: some View {
        EniroClimateScheduleView(viewModel: EniroClimateScheduleViewModel(apiService: HassApiService(urlCreator: URLCreator())))
    }
}

struct ClimateAutomationsView: View {
    let title: String
    let time: Date
    @Binding var climateBool: Entity
    let updateToggle: AsyncEntityClosure
    var spaces: String {
        var tempSpaces = ""
        for _ in 0 ..< max(2, 10 - title.count) {
            tempSpaces += " "
        }
        return tempSpaces
    }

    init(title: String, time: Date, climateBool: Binding<Entity>, updateToggle: @escaping AsyncEntityClosure) {
        self.title = title
        self.time = time
        self._climateBool = climateBool
        self.updateToggle = updateToggle
    }

    var body: some View {
        HStack {
            Text("\(title)\(spaces)\(time, style: .time)")
            Toggle("", isOn: $climateBool.isActive)
                .onChange(of: climateBool.isActive) {
                    Task {
                        await updateToggle(climateBool)
                    }
                }
        }
        .padding([.horizontal, .bottom], 8)
    }
}
