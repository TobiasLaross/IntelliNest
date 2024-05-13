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
                            .colorMultiply(isSelectedFanMode ? .yellow : .white)
                            .padding(.top)
                        Text(fanMode.rawValue.capitalized)
                            .font(.buttonFontLarge.bold())
                            .padding(.bottom)
                    }
                } else {
                    Text(fanMode.rawValue)
                        .font(isSelectedFanMode ? .buttonFontExtraLarge.bold() : .buttonFontExtraLarge)
                }
            }
            .frame(width: fanButtonSize, height: fanButtonSize, alignment: .center)
            .foregroundStyle(isSelectedFanMode ? .yellow : .white)
            .overlay {
                PrimaryContentBorderView(isSelected: isSelectedFanMode)
            }
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
