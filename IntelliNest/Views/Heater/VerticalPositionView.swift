//
//  VerticalPositionView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct VerticalPositionView: View {
    let mode: HeaterVerticalMode
    var verticalModeSelectedCallback: VerticalModeClosure

    var body: some View {
        HStack {
            VStack {
                VerticalButtonView(mode: .highest, selectedMode: mode, verticalModeSelectedCallback: verticalModeSelectedCallback)
                VerticalButtonView(mode: .position2, selectedMode: mode, verticalModeSelectedCallback: verticalModeSelectedCallback)
                VerticalButtonView(mode: .position3, selectedMode: mode, verticalModeSelectedCallback: verticalModeSelectedCallback)
                VerticalButtonView(mode: .position4, selectedMode: mode, verticalModeSelectedCallback: verticalModeSelectedCallback)
                VerticalButtonView(mode: .lowest, selectedMode: mode, verticalModeSelectedCallback: verticalModeSelectedCallback)
            }
            .padding([.top, .leading, .trailing])
            VStack {
                VerticalButtonView(mode: .auto, selectedMode: mode, verticalModeSelectedCallback: verticalModeSelectedCallback)
                VerticalButtonView(mode: .swing, selectedMode: mode, verticalModeSelectedCallback: verticalModeSelectedCallback)
            }
            .padding(.bottom)
        }
    }
}

struct HeaterVerticalPositionView_Previews: PreviewProvider {
    static var previews: some View {
        VerticalPositionView(mode: .lowest, verticalModeSelectedCallback: { _ in })
    }
}
