//
//  NumberPickerScrollView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-19.
//

import SwiftUI

struct NumberPickerScrollView: View {
    var entityId: EntityId
    @Binding var targetTemperature: Double
    var numberSelectedCallback: EntityIdDoubleClosure
    let pickerTextWidth: CGFloat
    @State var selectedNewNumber = false
    let strideFrom: CGFloat
    let strideTo: CGFloat
    let strideStep: CGFloat

    static let numberFormat: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 1
        return numberFormatter
    }()

    var body: some View {
        HStack {
            ScrollViewReader { scrollView in
                ZStack {
                    Rectangle()
                        .foregroundStyle(Color.topBarColor)
                        .cornerRadius(dashboardButtonCornerRadius)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(stride(from: strideFrom,
                                                 to: strideTo,
                                                 by: strideStep)), id: \.self) { index in
                                NumberTextView(pickerTextWidth: pickerTextWidth,
                                               targetTemperature: $targetTemperature,
                                               selectedNewTarget: $selectedNewNumber,
                                               index: index, numberPickerFormat: NumberPickerScrollView.numberFormat)
                                Rectangle().padding([.top, .bottom], 14).frame(width: 2).foregroundColor(.gray)
                            }
                        }
                    }
                    .onAppear {
                        scrollView.scrollTo(targetTemperature, anchor: .center)
                    }
                    .onChange(of: targetTemperature) {
                        scrollView.scrollTo(targetTemperature, anchor: .center)
                        if selectedNewNumber {
                            selectedNewNumber = false
                            numberSelectedCallback(entityId, targetTemperature)
                        }
                    }
                }
                .frame(width: pickerTextWidth * 3, height: 70, alignment: .leading)
            }
        }
    }

    init(entityId: EntityId,
         targetTemperature: Binding<Double>,
         numberSelectedCallback: @escaping EntityIdDoubleClosure,
         pickerTextWidth: CGFloat = 60,
         selectedNewNumber: Bool = false,
         strideFrom: CGFloat = 16,
         strideTo: CGFloat = 29,
         strideStep: CGFloat = 0.5) {
        self.entityId = entityId
        self._targetTemperature = targetTemperature
        self.numberSelectedCallback = numberSelectedCallback
        self.pickerTextWidth = pickerTextWidth
        self.selectedNewNumber = selectedNewNumber
        self.strideFrom = strideFrom
        self.strideTo = strideTo
        self.strideStep = strideStep
    }
}

private func previewHelperCallback(_: EntityId, _: Double) {}

struct NumberPickerScrollView_Previews: PreviewProvider {
    static var previews: some View {
        NumberPickerScrollView(entityId: .eniroClimateTemperature,
                               targetTemperature: .constant(22),
                               numberSelectedCallback: previewHelperCallback)
    }
}
