//
//  HassCircleButtonView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import SwiftUI

struct DashboardButtonView: View {
    var text: String
    var isActive: Bool
    var icon: Image?
    var iconWidth: CGFloat
    var iconHeight: CGFloat
    var iconForegroundColor: Color
    var backgroundColor: Color
    var circleSize: CGFloat
    var isLoading: Bool
    var isCircle: Bool
    let buttonFrameWidth: CGFloat
    let buttonFrameHeight: CGFloat
    let buttonCornerRadius: CGFloat
    var action: VoidClosure

    init(text: String,
         isActive: Bool = false,
         icon: Image? = nil,
         iconWidth: CGFloat = dashboardButtonImageSize,
         iconHeight: CGFloat = dashboardButtonImageSize,
         iconForegroundColor: Color = .white,
         backgroundColor: Color = topGrayColor,
         circleSize: CGFloat = dashboardCircleButtonFrameSize,
         isLoading: Bool,
         isCircle: Bool,
         buttonFrameWidth: CGFloat = dashboardButtonFrameWidth,
         buttonFrameHeight: CGFloat = dashboardButtonFrameHeight,
         buttonCornerRadius: CGFloat = dashboardButtonCornerRadius,
         action: @escaping VoidClosure) {
        self.text = text
        self.isActive = isActive
        self.icon = icon
        self.iconWidth = iconWidth
        self.iconHeight = iconHeight
        self.iconForegroundColor = iconForegroundColor
        self.backgroundColor = backgroundColor
        self.circleSize = circleSize
        self.isLoading = isLoading
        self.isCircle = isCircle
        self.buttonFrameWidth = buttonFrameWidth
        self.buttonFrameHeight = buttonFrameHeight
        self.buttonCornerRadius = buttonCornerRadius
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Group {
                    if isCircle {
                        Circle()
                            .frame(width: circleSize, height: circleSize)
                    } else {
                        RoundedRectangle(cornerRadius: buttonCornerRadius)
                            .frame(width: buttonFrameWidth, height: buttonFrameHeight)
                    }
                }
                .foregroundColor(backgroundColor)
                VStack {
                    icon.map {
                        $0
                            .resizable()
                            .frame(width: iconWidth, height: iconHeight)
                            .font(.system(size: iconWidth))
                            .foregroundColor(isActive ? .yellow : iconForegroundColor)
                    }
                    Text(text)
                        .font(.system(size: dashboardButtonTitleSize))
                        .padding(.horizontal, 4)
                        .foregroundColor(.white)
                }

                if isLoading {
                    VStack {
                        HStack {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .padding()
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: isCircle ? circleSize : buttonFrameWidth,
                   height: isCircle ? circleSize : buttonFrameHeight,
                   alignment: .center)
        }
    }
}
