//
//  Helpers.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-09.
//

import SwiftUI

let dashboardButtonBigTitleSize: CGFloat = 24
let dashboardButtonTitleSize: CGFloat = 14
let dashboardButtonImageSize: CGFloat = 35
let dashboardServiceButtonImageSIze: CGFloat = 20
let dashboardButtonFrameHeight: CGFloat = 90
let dashboardButtonFrameWidth: CGFloat = 90
let dashboardCircleButtonFrameSize: CGFloat = 80
let dashboardButtonCornerRadius: CGFloat = 20
let backgroundGrayIntensity = 0.21
let bodyColor = Color(red: backgroundGrayIntensity, green: backgroundGrayIntensity, blue: backgroundGrayIntensity)

struct HassButtonLabel: View {
    var button: AnyView
    let buttonFrameHeight: CGFloat
    let buttonFrameWidth: CGFloat
    let buttonCornerRadius: CGFloat

    init(button: AnyView,
         buttonFrameHeight: CGFloat = dashboardButtonFrameHeight,
         buttonFrameWidth: CGFloat = dashboardButtonFrameWidth,
         buttonCornerRadius: CGFloat = dashboardButtonCornerRadius) {
        self.button = button
        self.buttonFrameHeight = buttonFrameHeight
        self.buttonFrameWidth = buttonFrameWidth
        self.buttonCornerRadius = buttonCornerRadius
    }

    var body: some View {
        ZStack {
            Group {
                button
            }
            .frame(width: buttonFrameWidth, height: buttonFrameHeight, alignment: .center)
            .background(Color.topGrayColor)
            .cornerRadius(buttonCornerRadius)
        }
    }
}

struct NavButton: View {
    var buttonTitle: String
    var image: Image
    let buttonImageWidth: CGFloat
    let buttonImageHeight: CGFloat
    let isActive: Bool

    init(buttonTitle: String,
         image: Image,
         buttonImageWidth: CGFloat = dashboardButtonImageSize,
         buttonImageHeight: CGFloat = dashboardButtonImageSize,
         isActive: Bool = false) {
        self.buttonTitle = buttonTitle
        self.image = image
        self.buttonImageWidth = buttonImageWidth
        self.buttonImageHeight = buttonImageHeight
        self.isActive = isActive
    }

    var body: some View {
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
    }
}

struct VerticalDivider: View {
    let color: Color = .gray
    let width: CGFloat = 2
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
            .edgesIgnoringSafeArea(.horizontal)
    }
}

struct Helpers_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            NavButton(buttonTitle: "Test", image: Image(systemName: "bolt"))
        }
    }
}
