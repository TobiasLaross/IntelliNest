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
                                    .foregroundColor(isActive ? .yellow : .white)
                            }

                            if buttonTitle.isNotEmpty {
                                Text(buttonTitle)
                                    .lineLimit(2)
                                    .font(customFont)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 6)
                            }
                        }
                        .foregroundColor(.white)
                    }
            }
            .scaleEffect(tapped ? 0.9 : 1.0)
        }
    }

    init(buttonTitle: String,
         customFont: Font = .circleButtonFontMedium,
         isActive: Bool = false,
         activeColor: Color = .yellow,
         icon: Image?,
         buttonSize: CGFloat = 80,
         iconWidth: CGFloat = 20,
         iconHeight: CGFloat = 20,
         isLoading: Bool = false,
         action: @escaping MainActorVoidClosure) {
        self.buttonTitle = buttonTitle
        self.customFont = customFont
        self.isActive = isActive
        self.activeColor = activeColor
        self.icon = icon
        self.buttonSize = buttonSize
        self.iconWidth = iconWidth
        self.iconHeight = iconHeight
        self.isLoading = isLoading
        self.action = action
    }

    init(buttonTitle: String,
         customFont: Font = .circleButtonFontMedium,
         isActive: Bool = false,
         activeColor: Color = .yellow,
         icon: Image?,
         buttonSize: CGFloat = 80,
         imageSize: CGFloat = 20,
         isLoading: Bool = false,
         action: @escaping MainActorVoidClosure) {
        self.init(buttonTitle: buttonTitle,
                  customFont: customFont,
                  isActive: isActive,
                  activeColor: activeColor,
                  icon: icon,
                  buttonSize: buttonSize,
                  iconWidth: imageSize,
                  iconHeight: imageSize,
                  isLoading: isLoading,
                  action: action)
    }
}

#Preview {
    CircleButtonView(buttonTitle: "Service",
                     icon: .init(systemImageName: .bolt),
                     buttonSize: 20,
                     iconWidth: 33,
                     iconHeight: 33,
                     isLoading: false,
                     action: {})
}
