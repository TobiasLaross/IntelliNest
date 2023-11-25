//
//  CircleButtonView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-19.
//

import SwiftUI

struct CircleButtonView: View {
    @State private var tapped = false

    var buttonTitle: String
    var customFont: Font
    var isActive: Bool
    var activeColor: Color
    let buttonSize: CGFloat
    let icon: Image?
    let iconWidth: CGFloat
    let iconHeight: CGFloat
    let indicatorIcon: Image?
    var isLoading: Bool
    let action: MainActorVoidClosure

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
                Circle()
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundStyle(topGrayColor)
                    .overlay {
                        VStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)

                            } else if let icon {
                                icon
                                    .resizable()
                                    .frame(width: iconWidth, height: iconHeight, alignment: .center)
                                    .foregroundColor(isActive ? activeColor : .white)
                                    .contentTransition(.symbolEffect(.replace))
                            }

                            if buttonTitle.isNotEmpty {
                                Text(buttonTitle)
                                    .lineLimit(2)
                                    .font(customFont)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 7)
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .overlay {
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
                        }
                    }
            }
            .scaleEffect(tapped ? 0.9 : 1.0)
        }
    }

    init(buttonTitle: String,
         customFont: Font = .circleButtonFontMedium,
         isActive: Bool = false,
         activeColor: Color = .yellow,
         buttonSize: CGFloat = 80,
         icon: Image?,
         iconWidth: CGFloat = 20,
         iconHeight: CGFloat = 20,
         indicatorIcon: Image? = nil,
         isLoading: Bool = false,
         action: @escaping MainActorVoidClosure) {
        self.buttonTitle = buttonTitle
        self.customFont = customFont
        self.isActive = isActive
        self.activeColor = activeColor
        self.buttonSize = buttonSize
        self.icon = icon
        self.iconWidth = iconWidth
        self.iconHeight = iconHeight
        self.indicatorIcon = indicatorIcon
        self.isLoading = isLoading
        self.action = action
    }

    init(buttonTitle: String,
         customFont: Font = .circleButtonFontMedium,
         isActive: Bool = false,
         activeColor: Color = .yellow,
         buttonSize: CGFloat = 80,
         icon: Image?,
         imageSize: CGFloat = 20,
         isLoading: Bool = false,
         action: @escaping MainActorVoidClosure) {
        self.init(buttonTitle: buttonTitle,
                  customFont: customFont,
                  isActive: isActive,
                  activeColor: activeColor,
                  buttonSize: buttonSize,
                  icon: icon,
                  iconWidth: imageSize,
                  iconHeight: imageSize,
                  isLoading: isLoading,
                  action: action)
    }
}

#Preview {
    CircleButtonView(buttonTitle: "Service",
                     buttonSize: 20,
                     icon: .init(systemImageName: .bolt),
                     iconWidth: 33,
                     iconHeight: 33,
                     isLoading: false,
                     action: {})
}
