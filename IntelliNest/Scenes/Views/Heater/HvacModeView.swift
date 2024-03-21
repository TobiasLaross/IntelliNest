//
//  HvacModeView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-19.
//

import SwiftUI

struct HvacModeView: View {
    var heater: HeaterEntity
    let mode: HvacMode
    let imageSize: CGFloat = 20
    var hvacModeSelectedCallback: HeaterStringClosure

    var body: some View {
        HStack {
            Button {
                hvacModeSelectedCallback(heater, .off)
            } label: {
                HvacButtonLabel(hvacButton: AnyView(
                    VStack {
                        Image(systemName: "bolt.slash.fill").resizable()
                            .frame(width: imageSize, height: imageSize, alignment: .center)
                        Text("Av")
                    }
                ), isSelectedMode: mode == .off)
            }
            Button {
                hvacModeSelectedCallback(heater, .heat)
            } label: {
                HvacButtonLabel(hvacButton: AnyView(
                    VStack {
                        Image(systemName: "flame").resizable()
                            .frame(width: imageSize, height: imageSize, alignment: .center)
                        Text("Värme")
                    }
                ), isSelectedMode: mode == .heat)
            }
            Button {
                hvacModeSelectedCallback(heater, .cool)
            } label: {
                HvacButtonLabel(hvacButton: AnyView(
                    VStack {
                        Image(systemName: "snowflake").resizable()
                            .frame(width: imageSize, height: imageSize, alignment: .center)
                        Text("Kyla")
                    }
                ), isSelectedMode: mode == .cool)
            }
        }
    }
}
