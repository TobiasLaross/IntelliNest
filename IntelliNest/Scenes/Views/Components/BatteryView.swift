//
//  BatteryView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-09.
//

import SwiftUI

struct BatteryView: View {
    var level: Int
    var isCharging: Bool
    var degreeRotation: Double
    var width: CGFloat
    var height: CGFloat
    private let batteryCornerRadius: CGFloat = 15

    init(level: Int, isCharging: Bool, degreeRotation: Double = 0, width: CGFloat = 50, height: CGFloat = 90) {
        self.level = level
        self.isCharging = isCharging
        self.degreeRotation = degreeRotation
        self.width = width
        self.height = height
    }

    var body: some View {
        ZStack {
            Group {
                VStack {
                    Rectangle()
                        .frame(width: 0.25 * width, height: 0.07 * height, alignment: .center)
                        .padding(.bottom, -4)
                        .foregroundStyle(Color.topBarColor)
                    Rectangle()
                        .fill(Color.topBarColor)
                        .frame(width: width, height: height, alignment: .bottom)
                        .cornerRadius(batteryCornerRadius)
                        .padding(.top, -4)
                }
                Rectangle()
                    .fill(level > 60 ? .green : level > 30 ? .yellow : .red)
                    .frame(width: width, height: height, alignment: .bottom)
                    .scaleEffect(CGSize(width: 1, height: CGFloat(level) / 100.0), anchor: .bottom)
                    .cornerRadius(batteryCornerRadius)
                    .padding(.bottom, -5)
            }
            .rotationEffect(.degrees(degreeRotation))
            VStack {
                if isCharging {
                    Image(systemName: "bolt").foregroundColor(.yellow)
                }
                Text("\(level)%")
                    .font(Font.headline.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

struct BatteryView_Previews: PreviewProvider {
    static var previews: some View {
        BatteryView(level: 62, isCharging: false)
    }
}
