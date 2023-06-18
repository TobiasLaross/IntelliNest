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
    var body: some View {
        Text("\(index as NSNumber, formatter: numberPickerFormat)")
            .id(index)
            .font(targetTemperature == index ? .title : .body)
            .frame(width: pickerTextWidth, height: 30)
            .gesture(TapGesture().onEnded {
                selectedNewTarget = true
                targetTemperature = index
            })
            .foregroundColor(targetTemperature == index ?
                .white : .gray)
    }
}

struct NumberTextView_Previews: PreviewProvider {
    static var previews: some View {
        NumberTextView(pickerTextWidth: 20, targetTemperature: .constant(22), selectedNewTarget: .constant(false),
                       index: 10, numberPickerFormat: NumberFormatter())
    }
}
