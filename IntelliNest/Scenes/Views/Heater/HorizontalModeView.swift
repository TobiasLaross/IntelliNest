//
//  HorizontalModeView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct HorizontalModeView: View {
    var heater: HeaterEntity
    let mode: HorizontalMode
    let leftVaneTitle: String
    let rightVaneTitle: String
    var horizontalModeSelectedCallback: HeaterHorizontalModeClosure

    var body: some View {
        VStack {
            HStack {
                Button {
                    horizontalModeSelectedCallback(heater, HorizontalMode.oneLeft)
                } label: {
                    HorizontalButtonLabel(buttonTitle: leftVaneTitle, buttomImageName: nil,
                                          isSelectedMode: mode == HorizontalMode.oneLeft)
                }

                Button {
                    horizontalModeSelectedCallback(heater, HorizontalMode.two)
                } label: {
                    HorizontalButtonLabel(buttonTitle: nil, buttomImageName: "arrow.down.backward",
                                          isSelectedMode: mode == HorizontalMode.two)
                }

                Button {
                    horizontalModeSelectedCallback(heater, HorizontalMode.three)
                } label: {
                    HorizontalButtonLabel(buttonTitle: nil, buttomImageName: "arrow.down",
                                          isSelectedMode: mode == HorizontalMode.three)
                }

                Button {
                    horizontalModeSelectedCallback(heater, HorizontalMode.four)
                } label: {
                    HorizontalButtonLabel(buttonTitle: nil, buttomImageName: "arrow.down.forward",
                                          isSelectedMode: mode == HorizontalMode.four)
                }

                Button {
                    horizontalModeSelectedCallback(heater, HorizontalMode.fiveRight)
                } label: {
                    HorizontalButtonLabel(buttonTitle: rightVaneTitle, buttomImageName: nil,
                                          isSelectedMode: mode == HorizontalMode.fiveRight)
                }
            }
            .padding([.top, .leading, .trailing])
            HStack {
                Button {
                    horizontalModeSelectedCallback(heater, HorizontalMode.auto)
                } label: {
                    HorizontalButtonLabel(buttonTitle: "Auto", buttomImageName: nil,
                                          isSelectedMode: mode == HorizontalMode.auto)
                }
                Button {
                    horizontalModeSelectedCallback(heater, HorizontalMode.split)
                } label: {
                    HorizontalButtonLabel(buttonTitle: "Split", buttomImageName: nil,
                                          isSelectedMode: mode == HorizontalMode.split)
                }
                Button {
                    horizontalModeSelectedCallback(heater, HorizontalMode.swing)
                } label: {
                    HorizontalButtonLabel(buttonTitle: "Swing", buttomImageName: nil,
                                          isSelectedMode: mode == HorizontalMode.swing)
                }
            }
            .padding(.bottom)
        }
    }
}

struct HorizontalModeView_Previews: PreviewProvider {
    static var previews: some View {
        HorizontalModeView(heater: .init(entityId: .heaterCorridor), mode: .swing, leftVaneTitle: "Left", rightVaneTitle: "Right",
                           horizontalModeSelectedCallback: { _, _ in })
    }
}
