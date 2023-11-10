//
//  HorizontalButtonView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-10.
//

import SwiftUI

struct HorizontalButtonView: View {
    let horizontalButtonWidth: CGFloat = 50
    let horizontalButtonHeight: CGFloat = 50
    let horizontalButtonCornerRadius: CGFloat = 10
    var isSelectedMode: Bool {
        mode == selectedMode
    }

    let mode: HeaterHorizontalMode
    let selectedMode: HeaterHorizontalMode
    let buttonTitle: String?
    let buttonImageName: String?
    var horizontalModeSelectedCallback: HorizontalModeClosure

    var body: some View {
        Button {
            horizontalModeSelectedCallback(mode)
        } label: {
            Group {
                if let buttonTitle = buttonTitle {
                    if buttonTitle.count > 5 {
                        Text(buttonTitle).font(.caption)
                            .frame(width: 100, height: horizontalButtonHeight, alignment: .center)
                    } else if buttonTitle.count > 1 {
                        Text(buttonTitle).font(.body)
                            .frame(width: 60, height: horizontalButtonHeight, alignment: .center)
                    } else {
                        Text(buttonTitle).font(.title)
                            .frame(width: horizontalButtonWidth, height: horizontalButtonHeight, alignment: .center)
                    }
                }

                if let buttonImageName = buttonImageName {
                    Image(systemName: buttonImageName)
                        .frame(width: 50, height: 50, alignment: .center)
                }
            }
            .background(isSelectedMode ? .yellow : topGrayColor)
            .foregroundColor(isSelectedMode ? .black : .white)
            .cornerRadius(horizontalButtonCornerRadius)
        }
    }

    init(mode: HeaterHorizontalMode,
         selectedMode: HeaterHorizontalMode,
         buttonTitle: String? = nil,
         buttonImageName: String? = nil,
         horizontalModeSelectedCallback: @escaping HorizontalModeClosure) {
        self.mode = mode
        self.selectedMode = selectedMode
        self.buttonTitle = buttonTitle
        self.buttonImageName = buttonImageName
        self.horizontalModeSelectedCallback = horizontalModeSelectedCallback
    }
}

#Preview {
    HorizontalButtonView(mode: .auto,
                         selectedMode: .auto,
                         buttonTitle: "Vardagsrummet",
                         buttonImageName: nil,
                         horizontalModeSelectedCallback: { _ in })
}
