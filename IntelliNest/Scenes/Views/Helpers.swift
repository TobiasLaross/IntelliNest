//
//  Helpers.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-09.
//

import SwiftUI

let dashboardButtonBigTitleSize: CGFloat = 24
let dashboardButtonTitleSize: CGFloat = 14
let dashboardButtonImageSize: CGFloat = 40
let dashboardServiceButtonImageSIze: CGFloat = 20
let dashboardButtonFrameHeight: CGFloat = 110
let dashboardButtonFrameWidth: CGFloat = 110
let dashboardCircleButtonFrameSize: CGFloat = 80
let dashboardButtonCornerRadius: CGFloat = 20
let topGrayIntensity = 0.15
let backgroundGrayIntensity = 0.21
let topGrayColor = Color(red: topGrayIntensity, green: topGrayIntensity, blue: topGrayIntensity)
let navigationBarGrayColor = UIColor(red: topGrayIntensity, green: topGrayIntensity, blue: topGrayIntensity, alpha: 1)
let bodyColor = Color(red: backgroundGrayIntensity, green: backgroundGrayIntensity, blue: backgroundGrayIntensity)

struct HassButtonLabel: View {
    var button: AnyView
    let buttonFrameHeight: CGFloat
    let buttonFrameWidth: CGFloat
    let buttonCornerRadius: CGFloat

    init(button: AnyView, buttonFrameHeight: CGFloat = dashboardButtonFrameHeight,
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
            .background(topGrayColor)
            .cornerRadius(buttonCornerRadius)
        }
    }
}

struct NavButton: View {
    var buttonTitle: String
    var image: Image
    let buttonImageWidth: CGFloat
    let buttonImageHeight: CGFloat
    let buttonTitleSize: CGFloat
    let isActive: Bool

    init(buttonTitle: String,
         image: Image,
         buttonImageWidth: CGFloat = dashboardButtonImageSize,
         buttonImageHeight: CGFloat = dashboardButtonImageSize,
         buttonTitleSize: CGFloat = dashboardButtonTitleSize,
         isActive: Bool = false) {
        self.buttonTitle = buttonTitle
        self.image = image
        self.buttonImageWidth = buttonImageWidth
        self.buttonImageHeight = buttonImageHeight
        self.buttonTitleSize = buttonTitleSize
        self.isActive = isActive
    }

    var body: some View {
        VStack {
            image
                .resizable()
                .frame(width: buttonImageWidth, height: buttonImageHeight)
                .foregroundColor(isActive ? .yellow : .white)
            Text(buttonTitle)
                .font(.system(size: buttonTitleSize))
                .foregroundColor(.white)
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
