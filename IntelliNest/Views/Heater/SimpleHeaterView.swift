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
    let showDetailsClosure: MainActorEntityIDClosure
    @Binding var resetClimateTimeEntity: Entity
    @Binding private var resetClimateTimeDate: Date

    var isTimerModeEnabled: Bool
    let setTargetTemperatureClosure: EntityIdDoubleClosure
    let setHvacModeClosure: HeaterStringClosure
    let toggleTimerModeClosure: MainActorVoidClosure
    let setClimateScheduleTimeClosure: MainActorEntityClosure

    var body: some View {
        ZStack {
            if isTimerModeEnabled {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.lightBlue.opacity(0.3), lineWidth: 4)
                    .frame(height: height * 1.05)
                    .padding(.horizontal, 4)
            }
            VStack {
                INText(roomName, font: .title)
                INText("\(heater.currentTemperatureFormatted)℃", font: .title3)
                    .padding([.bottom, .horizontal])
                ThermometerGroupView(therm1: therm1, therm2: therm2, therm3: therm3, therm4: therm4)
                    .padding(.horizontal)

                ZStack(alignment: .center) {
                    VStack {
                        NumberPickerScrollView(entityId: heater.entityId,
                                               targetNumber: $heater.targetTemperature,
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
                                showDetailsClosure(heater.entityId)
                            } label: {
                                Image(imageName: .settings)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                            }
                            Button {
                                toggleTimerModeClosure()
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
                                        setClimateScheduleTimeClosure(resetClimateTimeEntity)
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
         resetClimateTimeEntity: Binding<Entity>,
         isTimerModeEnabled: Bool,
         showDetailsClosure: @escaping MainActorEntityIDClosure,
         setTargetTemperatureClosure: @escaping EntityIdDoubleClosure,
         setHvacModeClosure: @escaping HeaterStringClosure,
         toggleTimerModeClosure: @escaping MainActorVoidClosure,
         setClimateScheduleTimeClosure: @escaping MainActorEntityClosure) {
        self.roomName = roomName
        self.therm1 = therm1
        self.therm2 = therm2
        self.therm3 = therm3
        self.therm4 = therm4
        _heater = heater
        _resetClimateTimeEntity = resetClimateTimeEntity
        _resetClimateTimeDate = _resetClimateTimeEntity.date
        self.isTimerModeEnabled = isTimerModeEnabled
        self.showDetailsClosure = showDetailsClosure
        self.setTargetTemperatureClosure = setTargetTemperatureClosure
        self.setHvacModeClosure = setHvacModeClosure
        self.toggleTimerModeClosure = toggleTimerModeClosure
        self.setClimateScheduleTimeClosure = setClimateScheduleTimeClosure
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
                         resetClimateTimeEntity: .constant(.init(entityId: .eniroClimate)),
                         isTimerModeEnabled: true,
                         showDetailsClosure: { _ in },
                         setTargetTemperatureClosure: { _, _ in },
                         setHvacModeClosure: { _, _ in },
                         toggleTimerModeClosure: {},
                         setClimateScheduleTimeClosure: { _ in })
    }
}
