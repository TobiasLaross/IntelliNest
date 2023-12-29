//
//  ColorExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-10-20.
//

import SwiftUI

extension Color {
    private static let topGrayIntensity = 0.15
    static let lightBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let backgroundOverlay = Color.black.opacity(0.4)
    static let topGrayColor = Color(red: topGrayIntensity, green: topGrayIntensity, blue: topGrayIntensity)

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
