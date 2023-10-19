//
//  CoffeeMachineSchedulingView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-10-19.
//

import SwiftUI

struct CoffeeMachineSchedulingView: View {
    private var dateProxy: Binding<Date> {
        Binding<Date>(get: {
            coffeeMachineStartTime.date
        }, set: {
            coffeeMachineStartTime.date = $0
            setCoffeeMachineStartTime(coffeeMachineStartTime)
        })
    }

    @Binding var isVisible: Bool
    let title: String
    @Binding var coffeeMachineStartTime: Entity
    var coffeeMachineStartTimeEnabled: Entity
    let setCoffeeMachineStartTime: EntityClosure
    let toggleStartTimeEnabledAction: VoidClosure

    var body: some View {
        ZStack {
            FullScreenBackgroundOverlay()
                .onTapGesture {
                    isVisible = false
                }
            RoundedRectangle(cornerRadius: 20)
                .foregroundColor(.black)
                .frame(width: 220, height: 150)
            VStack(spacing: 16) {
                Text(title)
                    .font(.headline)
                HStack(spacing: 16) {
                    DatePicker("", selection: dateProxy, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                    Button {
                        toggleStartTimeEnabledAction()
                    } label: {
                        Image(systemImageName: .clock)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(coffeeMachineStartTimeEnabled.isActive ? .lightBlue : .white)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    CoffeeMachineSchedulingView(isVisible: .constant(true),
                                title: "Kaffemaskinen",
                                coffeeMachineStartTime: .constant(.init(entityId: .coffeeMachineStartTime)),
                                coffeeMachineStartTimeEnabled: .init(entityId: .coffeeMachineStartTimeEnabled),
                                setCoffeeMachineStartTime: { _ in },
                                toggleStartTimeEnabledAction: {})
}
