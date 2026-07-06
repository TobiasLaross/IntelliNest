//
//  NumberTextView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct NumberTextView: View {
    var pickerTextWidth: CGFloat
    @Binding var targetTemperature: Double
    @Binding var selectedNewTarget: Bool
    var index: Double
    let numberPickerFormat: NumberFormatter
    /// The value the backend confirms is actually set. When it matches this tile, a dot marks it so the user
    /// can see the real state catch up to their selection (used by the slow-to-apply purifier fans).
    var confirmedNumber: Double?

    var body: some View {
        Text("\(index as NSNumber, formatter: numberPickerFormat)")
            .id(index)
            .font(targetTemperature == index ? .title : .body)
            .frame(width: pickerTextWidth, height: 30)
            .gesture(TapGesture().onEnded {
                selectedNewTarget = true
                targetTemperature = index
            })
            .foregroundColor(targetTemperature == index ? .white : .white.opacity(0.667))
            .overlay(alignment: .bottom) {
                if confirmedNumber == index {
                    Circle()
                        .fill(Color.lightBlue)
                        .frame(width: 6, height: 6)
                        .offset(y: 7)
                }
            }
    }
}

struct NumberTextView_Previews: PreviewProvider {
    static var previews: some View {
        NumberTextView(pickerTextWidth: 20, targetTemperature: .constant(22), selectedNewTarget: .constant(false),
                       index: 10, numberPickerFormat: NumberFormatter())
    }
}
