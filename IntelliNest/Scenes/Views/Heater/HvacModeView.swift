//
//  HeaterGropuViews.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-19.
//

import SwiftUI

struct HvacModeView: View {
    var heater: HeaterEntity
    let mode: String
    let imageSize: CGFloat = 20
    var hvacModeSelectedCallback: HeaterStringClosure

    var body: some View {
        HStack {
            Button {
                hvacModeSelectedCallback(heater, HvacMode.off.rawValue)
            } label: {
                HvacButtonLabel(hvacButton: AnyView(
                    VStack {
                        Image(systemName: "bolt.slash.fill").resizable()
                            .frame(width: imageSize, height: imageSize, alignment: .center)
                        Text("Av")
                    }
                ), isSelectedMode: mode == HvacMode.off.rawValue)
            }
            Button {
                hvacModeSelectedCallback(heater, HvacMode.heat.rawValue)
            } label: {
                HvacButtonLabel(hvacButton: AnyView(
                    VStack {
                        Image(systemName: "flame").resizable()
                            .frame(width: imageSize, height: imageSize, alignment: .center)
                        Text("Värme")
                    }
                ), isSelectedMode: mode == HvacMode.heat.rawValue)
            }
            Button {
                hvacModeSelectedCallback(heater, HvacMode.cool.rawValue)
            } label: {
                HvacButtonLabel(hvacButton: AnyView(
                    VStack {
                        Image(systemName: "snowflake").resizable()
                            .frame(width: imageSize, height: imageSize, alignment: .center)
                        Text("Kyla")
                    }
                ), isSelectedMode: mode == HvacMode.cool.rawValue)
            }
        }
    }
}
