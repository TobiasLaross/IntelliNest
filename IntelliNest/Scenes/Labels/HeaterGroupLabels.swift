//
//  HeaterGroupLabels.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-19.
//

import SwiftUI

struct HvacButtonLabel: View {
    var hvacButton: AnyView
    var isSelectedMode: Bool
    let hvacButtonSize: CGFloat = 60
    let hvacButtonCornerRadius: CGFloat = 15
    var body: some View {
        Group {
            hvacButton
        }
        .frame(width: hvacButtonSize, height: hvacButtonSize, alignment: .center)
        .foregroundColor(isSelectedMode ? .yellow : .white)
        .font(isSelectedMode ? .buttonFontLarge.bold() : .buttonFontMedium)
        .overlay {
            PrimaryContentBorderView(isSelected: isSelectedMode)
        }
    }
}
