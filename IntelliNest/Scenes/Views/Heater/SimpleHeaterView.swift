//
//  SimpleHeaterView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct SimpleHeaterView: View {
    let width = 400.0
    let height = 300.0

    var roomName: String
    var therm1: Entity
    var therm2: Entity
    var therm3: Entity
    var therm4: Entity
    @Binding var heater: HeaterEntity
    @Binding var showDetails: Bool
    @Binding var resetClimateTime: Entity

    var isTimerModeEnabled: Bool
    let setTargetTemperatureClosure: EntityIdDoubleClosure
    let setHvacModeClosure: HeaterStringClosure
    let toggleTimerModeAction: VoidClosure
    let setClimateScheduleTime: EntityClosure

    var body: some View {
        ZStack {
            if isTimerModeEnabled {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.lightBlue.opacity(0.3), lineWidth: 4)
                    .frame(height: height * 1.05)
                    .padding(.horizontal, 4)
            }
            VStack {
                Text("\(roomName)")
                    .font(.title)
                    .foregroundColor(.white)
                Text("\(heater.currentTemperatureFormatted)℃")
                    .font(.title3)
                    .padding([.bottom, .leading, .trailing])
                    .foregroundColor(.white)
                ThermometerGroupView(therm1: therm1, therm2: therm2,
                                     therm3: therm3, therm4: therm4)
                    .padding([.leading, .trailing])

                ZStack(alignment: .center) {
                    VStack {
                        NumberPickerScrollView(entityId: heater.entityId,
                                               targetTemperature: $heater.targetTemperature,
                                               numberSelectedCallback: setTargetTemperatureClosure)
                            .padding(.vertical)
                        HvacModeView(heater: heater,
                                     mode: heater.state,
                                     hvacModeSelectedCallback: setHvacModeClosure)
                    }

                    HStack {
                        Spacer()
                        VStack {
                            Button {
                                showDetails = true
                            } label: {
                                Image(imageName: .settings)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                            }
                            Button {
                                toggleTimerModeAction()
                            } label: {
                                Image(systemImageName: .clock)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(isTimerModeEnabled ? .lightBlue : .white)
                            }
                            if isTimerModeEnabled {
                                DatePicker("", selection: $resetClimateTime.date, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .onChange(of: resetClimateTime.date, perform: { _ in
                                        setClimateScheduleTime(resetClimateTime)
                                    })
                            }
                        }
                        .padding(.trailing, 270) // Space between Buttons and VStack
                        Spacer()
                        Spacer()
                    }
                }
            }
            .background(bodyColor)
            .padding(.horizontal, isTimerModeEnabled ? 10 : 0)
            .padding(.vertical, 0)
        }
    }
}

struct SimpleHeaterView_Previews: PreviewProvider {
    static var previews: some View {
        let heater = HeaterEntity(entityId: EntityId.heaterCorridor)
        let therm = Entity(entityId: EntityId.thermGym)
        SimpleHeaterView(roomName: "Room",
                         therm1: therm,
                         therm2: therm,
                         therm3: therm,
                         therm4: therm,
                         heater: .constant(heater),
                         showDetails: .constant(false),
                         resetClimateTime: .constant(.init(entityId: .eniroClimate)),
                         isTimerModeEnabled: true,
                         setTargetTemperatureClosure: { _, _ in },
                         setHvacModeClosure: { _, _ in },
                         toggleTimerModeAction: {},
                         setClimateScheduleTime: { _ in })
    }
}
