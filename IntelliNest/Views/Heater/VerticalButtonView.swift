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
            .foregroundColor(isSelectedMode ? .yellow : .white)
            .overlay {
                PrimaryContentBorderView(isSelected: isSelectedMode)
            }
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
            "Auto"
        case .highest:
            "Upp"
        case .lowest:
            "Ner"
        case .swing:
            "Swing"
        default:
            nil
        }
    }

    var buttonImageName: String? {
        switch self {
        case .position2:
            "arrow.up.forward"
        case .position3:
            "arrow.right"
        case .position4:
            "arrow.down.forward"
        default:
            nil
        }
    }
}
