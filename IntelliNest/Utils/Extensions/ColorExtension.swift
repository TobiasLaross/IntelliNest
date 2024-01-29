//
//  ColorExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-10-20.
//

import SwiftUI

extension Color {
    private static let backgroundGrayIntensity = 0.21
    private static let topGrayIntensity = 0.15
    static let lightBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let appIconBlue = Color(hex: "#0097B2")
    static let appIconGreen = Color(hex: "#7ED957")
    static let appIconDark = Color(hex: "#133827")
    static let originalDarkBodyColor = Color(red: backgroundGrayIntensity, green: backgroundGrayIntensity, blue: backgroundGrayIntensity)
    static let originalTopBarColor = Color(red: topGrayIntensity, green: topGrayIntensity, blue: topGrayIntensity)
    static let backgroundOverlay = Color.black.opacity(0.4)
    static let bodyColor = appIconBlue.opacity(0.1)

    static let primaryContentBackground = blend(appIconDark, with: .black, ratio: 0.3)
    static let primaryContentBorder = Color.black.opacity(0.4)
    static let primaryContentSelectedBorder = Color.yellow

    static func blend(_ color1: Color, with color2: Color, ratio: CGFloat) -> Color {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)

        guard let cgColor1 = uiColor1.cgColor.components,
              let cgColor2 = uiColor2.cgColor.components else {
            return Color.clear
        }

        let ratio = min(max(ratio, 0), 1)

        let blendedRed = cgColor1[0] + (cgColor2[0] - cgColor1[0]) * ratio
        let blendedGreen = cgColor1[1] + (cgColor2[1] - cgColor1[1]) * ratio
        let blendedBlue = cgColor1[2] + (cgColor2[2] - cgColor1[2]) * ratio

        return Color(UIColor(red: blendedRed, green: blendedGreen, blue: blendedBlue, alpha: 1))
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
