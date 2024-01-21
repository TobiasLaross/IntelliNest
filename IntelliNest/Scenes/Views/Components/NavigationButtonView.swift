//
//  NavigationButtonView.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-17.
//

import SwiftUI

struct NavigationButtonView: View {
    @State private var tapped = false

    var buttonTitle: String
    var image: Image
    let buttonImageWidth: CGFloat
    let buttonImageHeight: CGFloat
    let frameSize: CGFloat
    let isActive: Bool
    let action: MainActorVoidClosure

    init(buttonTitle: String = "",
         image: Image,
         buttonImageWidth: CGFloat = dashboardButtonImageSize,
         buttonImageHeight: CGFloat = dashboardButtonImageSize,
         frameSize: CGFloat = dashboardButtonFrameWidth,
         isActive: Bool = false,
         action: @escaping MainActorVoidClosure = {}) {
        self.buttonTitle = buttonTitle
        self.image = image
        self.buttonImageWidth = buttonImageWidth
        self.buttonImageHeight = buttonImageHeight
        self.frameSize = frameSize
        self.isActive = isActive
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
            VStack {
                image
                    .resizable()
                    .frame(width: buttonImageWidth, height: buttonImageHeight)
                    .foregroundColor(isActive ? .yellow : .white)
                if buttonTitle.isNotEmpty {
                    Text(buttonTitle)
                        .font(.circleButtonFontMedium)
                        .foregroundColor(.white)
                }
            }
            .frame(width: frameSize, height: frameSize, alignment: .center)
            .background(Color.topBarColor)
            .cornerRadius(dashboardButtonCornerRadius)
        }
    }
}

#Preview {
    NavigationButtonView(buttonTitle: "Test", image: Image(systemName: "bolt"))
}
