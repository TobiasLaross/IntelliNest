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
    private let batteryCornerRadius: CGFloat = 15

    init(level: Int, isCharging: Bool, degreeRotation: Double = 0) {
        self.level = level
        self.isCharging = isCharging
        self.degreeRotation = degreeRotation
    }

    var body: some View {
        ZStack {
            Group {
                VStack {
                    Rectangle()
                        .frame(width: 12, height: 6, alignment: .center)
                        .padding(.bottom, -4)
                        .foregroundColor(Color(navigationBarGrayColor))
                    Rectangle()
                        .fill(Color(navigationBarGrayColor))
                        .frame(width: 50, height: 90, alignment: .bottom)
                        .cornerRadius(batteryCornerRadius)
                        .padding(.top, -4)
                }
                Rectangle()
                    .fill(level > 60 ? .green : level > 30 ? .yellow : .red)
                    .frame(width: 50, height: 90, alignment: .bottom)
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
