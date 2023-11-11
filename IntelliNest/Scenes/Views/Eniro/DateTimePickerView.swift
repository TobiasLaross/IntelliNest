//
//  DatePickerView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-14.
//

import SwiftUI

struct DateTimePickerView: View {
    let title: String
    let displayComponents: DatePickerComponents
    @Binding var dateTime: Entity
    @Binding var dateTimeEnabled: Entity
    @State var dateTimeLoaded = false
    let updateToggle: AsyncEntityClosure
    let setDateTimeClosure: EntityClosure

    var body: some View {
        HStack {
            Text(title)
            Spacer()
                .frame(width: 20)
            DatePicker("", selection: $dateTime.date, displayedComponents: displayComponents)
                .labelsHidden()
                .onChange(of: dateTime.date) {
                    if dateTimeLoaded {
                        dateTimeEnabled.isActive = true
                        setDateTimeClosure(dateTime)
                    } else {
                        dateTimeLoaded = true
                    }
                }
            Toggle("", isOn: $dateTimeEnabled.isActive)
                .onChange(of: dateTimeEnabled.isActive) {
                    Task {
                        await updateToggle(dateTimeEnabled)
                    }
                }
        }
        .padding([.horizontal, .bottom], 8)
    }
}

struct DatePickerView_Previews: PreviewProvider {
    static var previews: some View {
        DateTimePickerView(title: "Title",
                           displayComponents: .hourAndMinute,
                           dateTime: .constant(.init(entityId: .heaterCorridor)),
                           dateTimeEnabled: .constant(.init(entityId: .heaterCorridor)),
                           updateToggle: { _ in },
                           setDateTimeClosure: { _ in })
    }
}
