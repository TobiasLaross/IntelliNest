//
//  DashboardButtonView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import SwiftUI

struct DashboardButtonView: View {
    @State private var tapped = false

    var text: String
    var isActive: Bool
    var activeColor: Color
    var icon: Image?
    var iconWidth: CGFloat
    var iconHeight: CGFloat
    var iconForegroundColor: Color
    var backgroundColor: Color
    var isLoading: Bool
    let indicatorIcon: Image?
    let buttonFrameWidth: CGFloat
    let buttonFrameHeight: CGFloat
    let buttonCornerRadius: CGFloat
    var action: MainActorVoidClosure

    init(text: String,
         isActive: Bool = false,
         activeColor: Color = .yellow,
         icon: Image? = nil,
         iconWidth: CGFloat = dashboardButtonImageSize,
         iconHeight: CGFloat = dashboardButtonImageSize,
         iconForegroundColor: Color = .white,
         backgroundColor: Color = topGrayColor,
         circleSize: CGFloat = dashboardCircleButtonFrameSize,
         isLoading: Bool = false,
         indicatorIcon: Image? = nil,
         buttonFrameWidth: CGFloat = dashboardButtonFrameWidth,
         buttonFrameHeight: CGFloat = dashboardButtonFrameHeight,
         buttonCornerRadius: CGFloat = dashboardButtonCornerRadius,
         action: @escaping MainActorVoidClosure) {
        self.text = text
        self.isActive = isActive
        self.activeColor = activeColor
        self.icon = icon
        self.iconWidth = iconWidth
        self.iconHeight = iconHeight
        self.iconForegroundColor = iconForegroundColor
        self.backgroundColor = backgroundColor
        self.isLoading = isLoading
        self.indicatorIcon = indicatorIcon
        self.buttonFrameWidth = buttonFrameWidth
        self.buttonFrameHeight = buttonFrameHeight
        self.buttonCornerRadius = buttonCornerRadius
        self.action = action
    }

    var body: some View {
        Button {
            action()
            withAnimation(.spring()) {
                tapped = true
                Task { @MainActor in
                    try? await Task.sleep(seconds: 0.1)
                    tapped = false
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: buttonCornerRadius)
                    .frame(width: buttonFrameWidth, height: buttonFrameHeight)
                    .foregroundColor(backgroundColor)
                VStack {
                    icon.map {
                        $0
                            .resizable()
                            .frame(width: iconWidth, height: iconHeight)
                            .font(.system(size: iconWidth))
                            .foregroundColor(isActive ? activeColor : iconForegroundColor)
                    }
                    Text(text)
                        .font(.system(size: dashboardButtonTitleSize))
                        .padding(.horizontal, 4)
                        .foregroundColor(.white)
                }

                if let indicatorIcon {
                    VStack {
                        HStack {
                            indicatorIcon
                                .foregroundColor(.lightBlue)
                                .padding()
                            Spacer()
                        }
                        Spacer()
                    }
                } else if isLoading {
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
            .scaleEffect(tapped ? 0.9 : 1.0)
            .frame(width: buttonFrameWidth, height: buttonFrameHeight, alignment: .center)
        }
    }
}
