//
//  DatePickerView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-14.
//

import SwiftUI

struct EniroClimateSchedulePickerView: View {
    let title: String
    let displayComponents: DatePickerComponents
    @Binding var climate: Entity
    @Binding var climateBool: Entity
    @State var climateLoaded = false
    let updateToggle: AsyncEntityClosure
    let setClimateScheduleDate: AsyncEntityClosure

    var body: some View {
        HStack {
            Text(title)
            Spacer()
                .frame(width: 20)
            DatePicker("", selection: $climate.date, displayedComponents: displayComponents)
                .labelsHidden()
                .onChange(of: climate.date, perform: { _ in
                    if climateLoaded {
                        climateBool.isActive = true
                        Task {
                            await setClimateScheduleDate(climate)
                        }
                    } else {
                        climateLoaded = true
                    }
                })
            Toggle("", isOn: $climateBool.isActive)
                .onChange(of: climateBool.isActive, perform: { _ in
                    Task {
                        await updateToggle(climateBool)
                    }
                })
        }
        .padding([.horizontal, .bottom], 8)
    }
}

struct DatePickerView_Previews: PreviewProvider {
    static var previews: some View {
        EniroClimateSchedulePickerView(title: "Title",
                                       displayComponents: .hourAndMinute,
                                       climate: .constant(.init(entityId: .heaterCorridor)),
                                       climateBool: .constant(.init(entityId: .heaterCorridor)),
                                       updateToggle: { _ in },
                                       setClimateScheduleDate: { _ in })
    }
}
