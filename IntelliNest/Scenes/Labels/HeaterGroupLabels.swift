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
        .background(isSelectedMode ? .yellow : topGrayColor)
        .foregroundColor(isSelectedMode ? .black : .white)
        .cornerRadius(hvacButtonCornerRadius)
    }
}

struct FanButtonLabel: View {
    var fanButton: AnyView
    var isSelectedMode: Bool
    let fanButtonSize: CGFloat = 50
    let fanButtonCornerRadius: CGFloat = 10
    var body: some View {
        Group {
            fanButton
        }
        .frame(width: fanButtonSize, height: fanButtonSize, alignment: .center)
        .background(isSelectedMode ? .yellow : topGrayColor)
        .foregroundColor(isSelectedMode ? .black : .white)
        .cornerRadius(fanButtonCornerRadius)
    }
}

struct HorizontalButtonLabel: View {
    let buttonTitle: String?
    let buttomImageName: String?
    var isSelectedMode: Bool
    let horizontalButtonWidth: CGFloat = 50
    let horizontalButtonHeight: CGFloat = 50
    let horizontalButtonCornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if let buttonTitle = buttonTitle {
                if buttonTitle.count > 5 {
                    Text(buttonTitle).font(.caption)
                        .frame(width: 95, height: horizontalButtonHeight, alignment: .center)
                } else if buttonTitle.count > 1 {
                    Text(buttonTitle).font(.body)
                        .frame(width: 60, height: horizontalButtonHeight, alignment: .center)
                } else {
                    Text(buttonTitle).font(.title)
                        .frame(width: horizontalButtonWidth, height: horizontalButtonHeight, alignment: .center)
                }
            }

            if let buttomImageName = buttomImageName {
                Image(systemName: buttomImageName)
                    .frame(width: 50, height: 50, alignment: .center)
            }
        }
        .background(isSelectedMode ? .yellow : topGrayColor)
        .foregroundColor(isSelectedMode ? .black : .white)
        .cornerRadius(horizontalButtonCornerRadius)
    }
}

struct VerticalButtonLabel: View {
    let buttonTitle: String?
    let buttomImageName: String?
    var isSelectedMode: Bool
    let verticalButtonWidth: CGFloat = 50
    let verticalButtonHeight: CGFloat = 50
    let verticalButtonCornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if let buttonTitle = buttonTitle {
                if buttonTitle.count > 1 {
                    Text(buttonTitle).font(.body)
                        .frame(width: verticalButtonWidth, height: verticalButtonHeight, alignment: .center)
                } else {
                    Text(buttonTitle).font(.title)
                        .frame(width: verticalButtonWidth, height: verticalButtonHeight, alignment: .center)
                }
            }

            if let buttomImageName = buttomImageName {
                Image(systemName: buttomImageName)
                    .frame(width: 50, height: 50, alignment: .center)
            }
        }
        .background(isSelectedMode ? .yellow : topGrayColor)
        .foregroundColor(isSelectedMode ? .black : .white)
        .cornerRadius(verticalButtonCornerRadius)
    }
}
