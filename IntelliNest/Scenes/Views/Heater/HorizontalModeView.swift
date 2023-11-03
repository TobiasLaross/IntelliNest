//
//  HorizontalModeView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct HorizontalModeView: View {
    let mode: HeaterHorizontalMode
    let leftVaneTitle: String
    let rightVaneTitle: String
    var horizontalModeSelectedCallback: HorizontalModeClosure

    var body: some View {
        VStack {
            HStack {
                HorizontalButtonView(mode: .oneLeft,
                                     selectedMode: mode,
                                     buttonTitle: leftVaneTitle,
                                     horizontalModeSelectedCallback: horizontalModeSelectedCallback)
                HorizontalButtonView(mode: .two,
                                     selectedMode: mode,
                                     buttonImageName: "arrow.down.backward",
                                     horizontalModeSelectedCallback: horizontalModeSelectedCallback)
                HorizontalButtonView(mode: .three,
                                     selectedMode: mode,
                                     buttonImageName: "arrow.down",
                                     horizontalModeSelectedCallback: horizontalModeSelectedCallback)
                HorizontalButtonView(mode: .four,
                                     selectedMode: mode,
                                     buttonImageName: "arrow.down.forward",
                                     horizontalModeSelectedCallback: horizontalModeSelectedCallback)
                HorizontalButtonView(mode: .fiveRight,
                                     selectedMode: mode,
                                     buttonTitle: rightVaneTitle,
                                     horizontalModeSelectedCallback: horizontalModeSelectedCallback)
            }
            .padding([.top, .leading, .trailing])
            HStack {
                HorizontalButtonView(mode: .auto,
                                     selectedMode: mode,
                                     buttonTitle: "Auto",
                                     horizontalModeSelectedCallback: horizontalModeSelectedCallback)
                HorizontalButtonView(mode: .split,
                                     selectedMode: mode,
                                     buttonTitle: "Split",
                                     horizontalModeSelectedCallback: horizontalModeSelectedCallback)
                HorizontalButtonView(mode: .swing,
                                     selectedMode: mode,
                                     buttonTitle: "Swing",
                                     horizontalModeSelectedCallback: horizontalModeSelectedCallback)
            }
            .padding(.bottom)
        }
    }
}

struct HorizontalModeView_Previews: PreviewProvider {
    static var previews: some View {
        HorizontalModeView(mode: .swing, leftVaneTitle: "Left", rightVaneTitle: "Right",
                           horizontalModeSelectedCallback: { _ in })
    }
}
