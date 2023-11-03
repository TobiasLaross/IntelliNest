//
//  FanModeButtonView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-10.
//

import SwiftUI

struct FanModeButtonView: View {
    let fanButtonSize: CGFloat = 50
    let fanButtonCornerRadius: CGFloat = 10
    let imageSize: CGFloat = 15
    var isSelectedFanMode: Bool {
        fanMode == selectedFanMode
    }

    var fanMode: HeaterFanMode
    var selectedFanMode: HeaterFanMode
    var image: Image?
    var fanModeSelectedCallback: FanModeClosure

    var body: some View {
        Button {
            fanModeSelectedCallback(fanMode)
        } label: {
            Group {
                if let image {
                    VStack {
                        image
                            .resizable()
                            .frame(width: imageSize, height: imageSize, alignment: .center)
                            .colorMultiply(isSelectedFanMode ? .black : .white)
                            .padding(.top)
                        Text(fanMode.rawValue.capitalized)
                            .font(.system(size: dashboardButtonTitleSize))
                            .padding(.bottom)
                    }
                } else {
                    Text(fanMode.rawValue)
                        .font(.system(size: dashboardButtonBigTitleSize))
                }
            }
            .frame(width: fanButtonSize, height: fanButtonSize, alignment: .center)
            .background(isSelectedFanMode ? .yellow : topGrayColor)
            .foregroundColor(isSelectedFanMode ? .black : .white)
            .cornerRadius(fanButtonCornerRadius)
        }
    }
}

#Preview {
    HStack {
        FanModeButtonView(fanMode: .auto, selectedFanMode: .one, image: .init(imageName: .refresh), fanModeSelectedCallback: { _ in })
        FanModeButtonView(fanMode: .auto, selectedFanMode: .auto, image: .init(imageName: .refresh), fanModeSelectedCallback: { _ in })
        FanModeButtonView(fanMode: .one, selectedFanMode: .one, fanModeSelectedCallback: { _ in })
        FanModeButtonView(fanMode: .two, selectedFanMode: .one, fanModeSelectedCallback: { _ in })
    }
}
