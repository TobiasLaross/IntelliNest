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

struct HassCircleButtonLabelOld: View {
    var dashboardButton: AnyView
    var buttonFrameSize: CGFloat

    init(dashboardButton: AnyView, buttonFrameSize: CGFloat = dashboardCircleButtonFrameSize) {
        self.dashboardButton = dashboardButton
        self.buttonFrameSize = buttonFrameSize
    }

    var body: some View {
        Group {
            dashboardButton
        }
        .frame(width: buttonFrameSize, height: buttonFrameSize, alignment: .center)
        .background(topGrayColor)
        .foregroundColor(.white)
        .cornerRadius(.infinity)
    }
}

struct SwitchButton<T: EntityProtocol>: View {
    @Binding var entity: T
    var buttonTitle: String
    var activeImageName: String
    var defaultImageName: String
    let isSystemName: Bool
    let buttonImageSize: CGFloat
    let buttonTitleSize: CGFloat
    var isLoading: Bool

    init(entity: Binding<T>,
         buttonTitle: String,
         activeImageName: String,
         defaultImageName: String,
         isSystemName: Bool = true,
         buttonImageSize: CGFloat = dashboardButtonImageSize,
         buttonTitleSize: CGFloat = dashboardButtonTitleSize,
         isLoading: Bool = false) {
        self._entity = entity
        self.buttonTitle = buttonTitle
        self.activeImageName = activeImageName
        self.defaultImageName = defaultImageName
        self.isSystemName = isSystemName
        self.buttonImageSize = buttonImageSize
        self.buttonTitleSize = buttonTitleSize
        self.isLoading = isLoading
    }

    var body: some View {
        ZStack {
            VStack {
                if isSystemName {
                    Image(systemName: entity.isActive ? activeImageName : defaultImageName)
                        .font(.system(size: buttonImageSize))
                        .foregroundColor(entity.isActive ? .yellow : .white)
                } else {
                    Image(entity.isActive ? activeImageName : defaultImageName)
                        .resizable()
                        .frame(width: buttonImageSize, height: buttonImageSize, alignment: .center)
                        .foregroundColor(.yellow)
                }

                if buttonTitle != "" {
                    Text(buttonTitle)
                        .font(.system(size: buttonTitleSize))
                        .padding(.horizontal, 4)
                        .foregroundColor(.white)
                }
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
    }
}

struct ServiceButton: View {
    var buttonTitle: String
    var imageName: String
    let isSystemName: Bool
    let imageSize: CGFloat
    var isLoading: Bool

    init(buttonTitle: String, imageName: String, isSystemName: Bool = true, isLoading: Bool = false,
         imageSize: CGFloat = dashboardServiceButtonImageSIze) {
        self.buttonTitle = buttonTitle
        self.imageName = imageName
        self.isSystemName = isSystemName
        self.imageSize = imageSize
        self.isLoading = isLoading
    }

    var body: some View {
        ZStack {
            VStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)

                } else {
                    if isSystemName {
                        Image(systemName: imageName)
                            .font(.system(size: imageSize))
                    } else {
                        Image(imageName)
                            .resizable()
                            .frame(width: imageSize, height: imageSize, alignment: .center)
                    }
                }

                Text(buttonTitle)
                    .font(.system(size: dashboardButtonTitleSize))
            }
            .foregroundColor(.white)
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
            ServiceButton(buttonTitle: "Ladda upp från bil", imageName: "arrow.up",
                          isLoading: true)
        }
    }
}
