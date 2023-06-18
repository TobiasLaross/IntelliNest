//
//  HeaterVerticalPositionView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct HeaterVerticalPositionView: View {
    var heater: HeaterEntity
    let mode: HeaterVerticalPosition
    var verticalModeSelectedCallback: HeaterVerticalModeClosure

    var body: some View {
        HStack {
            VStack {
                Button {
                    verticalModeSelectedCallback(heater, HeaterVerticalPosition.highest)
                } label: {
                    VerticalButtonLabel(buttonTitle: "Upp", buttomImageName: nil,
                                        isSelectedMode: mode == HeaterVerticalPosition.highest)
                }

                Button {
                    verticalModeSelectedCallback(heater, HeaterVerticalPosition.position2)
                } label: {
                    VerticalButtonLabel(buttonTitle: nil, buttomImageName: "arrow.up.forward",
                                        isSelectedMode: mode == HeaterVerticalPosition.position2)
                }

                Button {
                    verticalModeSelectedCallback(heater, HeaterVerticalPosition.position3)
                } label: {
                    VerticalButtonLabel(buttonTitle: nil, buttomImageName: "arrow.right",
                                        isSelectedMode: mode == HeaterVerticalPosition.position3)
                }

                Button {
                    verticalModeSelectedCallback(heater, HeaterVerticalPosition.position4)
                } label: {
                    VerticalButtonLabel(buttonTitle: nil, buttomImageName: "arrow.down.forward",
                                        isSelectedMode: mode == HeaterVerticalPosition.position4)
                }

                Button {
                    verticalModeSelectedCallback(heater, HeaterVerticalPosition.lowest)
                } label: {
                    VerticalButtonLabel(buttonTitle: "Ner", buttomImageName: nil,
                                        isSelectedMode: mode == HeaterVerticalPosition.lowest)
                }
            }
            .padding([.top, .leading, .trailing])
            VStack {
                Button {
                    verticalModeSelectedCallback(heater, HeaterVerticalPosition.auto)
                } label: {
                    VerticalButtonLabel(buttonTitle: "Auto", buttomImageName: nil,
                                        isSelectedMode: mode == HeaterVerticalPosition.auto)
                }

                Button {
                    verticalModeSelectedCallback(heater, HeaterVerticalPosition.swing)
                } label: {
                    VerticalButtonLabel(buttonTitle: "Swing", buttomImageName: nil,
                                        isSelectedMode: mode == HeaterVerticalPosition.swing)
                }
            }
            .padding(.bottom)
        }
    }
}

struct HeaterVerticalPositionView_Previews: PreviewProvider {
    static var previews: some View {
        HeaterVerticalPositionView(heater: .init(entityId: .heaterCorridor),
                                   mode: .lowest, verticalModeSelectedCallback: { _, _ in })
    }
}
