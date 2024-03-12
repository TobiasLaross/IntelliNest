//
//  LimitPickerView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-24.
//

import SwiftUI

struct LimitPickerView: View {
    let limitEntity: InputNumberEntity
    let saveChargerLimit: EntityIdDoubleClosure
    @State var currentLimit: Double
    let pickerTextWidth: CGFloat = 60
    var body: some View {
        ZStack {
            FullScreenBackgroundOverlay()
                .onTapGesture {
                    saveChargerLimit(limitEntity.entityId, currentLimit)
                }
            RoundedRectangle(cornerRadius: 40)
                .foregroundColor(.black)
                .opacity(0.7)
                .frame(width: pickerTextWidth * 4,
                       height: 160)
                .onTapGesture {
                    saveChargerLimit(limitEntity.entityId, currentLimit)
                }
            VStack {
                NumberPickerScrollView(entityId: limitEntity.entityId,
                                       targetTemperature: $currentLimit,
                                       numberSelectedCallback: saveChargerLimit,
                                       pickerTextWidth: pickerTextWidth,
                                       strideFrom: 50,
                                       strideTo: 101,
                                       strideStep: 10)
            }
        }
    }
}

struct LimitPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LimitPickerView(limitEntity: .init(entityId: .lynkDoorLock), saveChargerLimit: { _, _ in }, currentLimit: 50)
    }
}
