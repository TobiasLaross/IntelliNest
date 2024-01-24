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
    @Binding var resetClimateTimeEntity: Entity
    @Binding private var resetClimateTimeDate: Date

    var isTimerModeEnabled: Bool
    let setTargetTemperatureClosure: EntityIdDoubleClosure
    let setHvacModeClosure: HeaterStringClosure
    let toggleTimerModeAction: MainActorVoidClosure
    let setClimateScheduleTime: MainActorEntityClosure

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
                                     mode: heater.hvacMode,
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
                                DatePicker("", selection: $resetClimateTimeDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .onChange(of: resetClimateTimeDate) {
                                        setClimateScheduleTime(resetClimateTimeEntity)
                                    }
                            }
                        }
                        .padding(.trailing, 270) // Space between Buttons and VStack
                        Spacer()
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, isTimerModeEnabled ? 10 : 0)
            .padding(.vertical, 0)
        }
    }

    init(roomName: String, therm1: Entity, therm2: Entity, therm3: Entity, therm4: Entity,
         heater: Binding<HeaterEntity>,
         showDetails: Binding<Bool>,
         resetClimateTimeEntity: Binding<Entity>,
         isTimerModeEnabled: Bool,
         setTargetTemperatureClosure: @escaping EntityIdDoubleClosure,
         setHvacModeClosure: @escaping HeaterStringClosure,
         toggleTimerModeAction: @escaping MainActorVoidClosure,
         setClimateScheduleTime: @escaping MainActorEntityClosure) {
        self.roomName = roomName
        self.therm1 = therm1
        self.therm2 = therm2
        self.therm3 = therm3
        self.therm4 = therm4
        _heater = heater
        _showDetails = showDetails
        _resetClimateTimeEntity = resetClimateTimeEntity
        _resetClimateTimeDate = _resetClimateTimeEntity.date
        self.isTimerModeEnabled = isTimerModeEnabled
        self.setTargetTemperatureClosure = setTargetTemperatureClosure
        self.setHvacModeClosure = setHvacModeClosure
        self.toggleTimerModeAction = toggleTimerModeAction
        self.setClimateScheduleTime = setClimateScheduleTime
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
                         resetClimateTimeEntity: .constant(.init(entityId: .eniroClimate)),
                         isTimerModeEnabled: true,
                         setTargetTemperatureClosure: { _, _ in },
                         setHvacModeClosure: { _, _ in },
                         toggleTimerModeAction: {},
                         setClimateScheduleTime: { _ in })
    }
}
