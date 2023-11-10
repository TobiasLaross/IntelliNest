//
//  VerticalButtonView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-10.
//

import SwiftUI

struct VerticalButtonView: View {
    let verticalButtonWidth: CGFloat = 50
    let verticalButtonHeight: CGFloat = 50
    let verticalButtonCornerRadius: CGFloat = 10
    var isSelectedMode: Bool {
        mode == selectedMode
    }

    let mode: HeaterVerticalMode
    let selectedMode: HeaterVerticalMode
    var verticalModeSelectedCallback: VerticalModeClosure

    var body: some View {
        Button {
            verticalModeSelectedCallback(mode)
        } label: {
            Group {
                if let buttonTitle = mode.buttonTitle {
                    if buttonTitle.count > 1 {
                        Text(buttonTitle).font(.body)
                            .frame(width: verticalButtonWidth, height: verticalButtonHeight, alignment: .center)
                            .padding(.horizontal, 5)
                    } else {
                        Text(buttonTitle).font(.title)
                            .frame(width: verticalButtonWidth, height: verticalButtonHeight, alignment: .center)
                    }
                }

                if let buttonImageName = mode.buttonImageName {
                    Image(systemName: buttonImageName)
                        .frame(width: 50, height: 50, alignment: .center)
                }
            }
            .background(isSelectedMode ? .yellow : topGrayColor)
            .foregroundColor(isSelectedMode ? .black : .white)
            .cornerRadius(verticalButtonCornerRadius)
        }
    }
}

#Preview {
    VerticalButtonView(mode: .auto, selectedMode: .highest, verticalModeSelectedCallback: { _ in })
}

private extension HeaterVerticalMode {
    var buttonTitle: String? {
        switch self {
        case .auto:
            return "Auto"
        case .highest:
            return "Upp"
        case .lowest:
            return "Ner"
        case .swing:
            return "Swing"
        default:
            return nil
        }
    }

    var buttonImageName: String? {
        switch self {
        case .position2:
            return "arrow.up.forward"
        case .position3:
            return "arrow.right"
        case .position4:
            return "arrow.down.forward"
        default:
            return nil
        }
    }
}
