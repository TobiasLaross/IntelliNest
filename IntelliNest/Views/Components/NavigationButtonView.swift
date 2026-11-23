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
    let badge: String?
    let action: MainActorVoidClosure

    init(buttonTitle: String = "",
         image: Image,
         buttonImageWidth: CGFloat = dashboardButtonImageSize,
         buttonImageHeight: CGFloat = dashboardButtonImageSize,
         frameSize: CGFloat = dashboardButtonFrameWidth,
         isActive: Bool = false,
         badge: String? = nil,
         action: @escaping MainActorVoidClosure = {}) {
        self.buttonTitle = buttonTitle
        self.image = image
        self.buttonImageWidth = buttonImageWidth
        self.buttonImageHeight = buttonImageHeight
        self.frameSize = frameSize
        self.isActive = isActive
        self.badge = badge
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
                        .font(.buttonFontMedium)
                        .foregroundColor(.white)
                }
            }
            .frame(width: frameSize, height: frameSize, alignment: .center)
            .background(LinearGradient.buttonGradient)
            .cornerRadius(dashboardButtonCornerRadius)
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.yellow, in: Capsule())
                        .offset(x: 6, y: -6)
                }
            }
        }
    }
}

#Preview {
    NavigationButtonView(buttonTitle: "Test", image: Image(systemName: "bolt"))
}
