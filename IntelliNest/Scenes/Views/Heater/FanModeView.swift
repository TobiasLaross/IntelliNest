//
//  FanModeView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct FanModeView: View {
    var heater: HeaterEntity
    let mode: FanMode
    var fanModeSelectedCallback: HeaterFanModeClosure
    let imageSize: CGFloat = 15

    var body: some View {
        HStack {
            Button {
                fanModeSelectedCallback(heater, FanMode.auto)
            } label: {
                FanButtonLabel(fanButton: AnyView(
                    VStack {
                        Image(imageName: .refresh)
                            .resizable()
                            .frame(width: imageSize, height: imageSize, alignment: .center)
                            .padding(.top)
                        Text("Auto")
                            .font(.system(size: dashboardButtonTitleSize))
                            .padding(.bottom)
                    }
                ), isSelectedMode: mode == FanMode.auto)
            }
            Button {
                fanModeSelectedCallback(heater, FanMode.one)
            } label: {
                FanButtonLabel(fanButton: AnyView(
                    Text("1").font(.system(size: dashboardButtonBigTitleSize))
                ), isSelectedMode: mode == FanMode.one)
            }
            Button {
                fanModeSelectedCallback(heater, FanMode.two)
            } label: {
                FanButtonLabel(fanButton: AnyView(
                    Text("2").font(.system(size: dashboardButtonBigTitleSize))
                ), isSelectedMode: mode == FanMode.two)
            }
            Button {
                fanModeSelectedCallback(heater, FanMode.three)
            } label: {
                FanButtonLabel(fanButton: AnyView(
                    Text("3").font(.system(size: dashboardButtonBigTitleSize))
                ), isSelectedMode: mode == FanMode.three)
            }
            Button {
                fanModeSelectedCallback(heater, FanMode.four)
            } label: {
                FanButtonLabel(fanButton: AnyView(
                    Text("4").font(.system(size: dashboardButtonBigTitleSize))
                ), isSelectedMode: mode == FanMode.four)
            }
            Button {
                fanModeSelectedCallback(heater, FanMode.five)
            } label: {
                FanButtonLabel(fanButton: AnyView(
                    Text("5").font(.system(size: dashboardButtonBigTitleSize))
                ), isSelectedMode: mode == FanMode.five)
            }
        }
    }
}

struct FanModeView_Previews: PreviewProvider {
    static var previews: some View {
        FanModeView(heater: .init(entityId: .heaterCorridor),
                    mode: FanMode.one, fanModeSelectedCallback: { _, _ in })
    }
}
