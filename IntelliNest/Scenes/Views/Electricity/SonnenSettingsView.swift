//
//  SonnenSettingsView.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-18.
//

import SwiftUI

struct SonnenSettingsView: View {
    @ObservedObject var viewModel: ElectricityViewModel
    @State private var isAutomationEnabled: Bool
    @State private var selectedMode: SonnenOperationModes
    @State private var selectedWatt: Int

    let chargeValues = [0, 1000, 5000, 7000, 10000]

    var body: some View {
        ZStack {
            FullScreenBackgroundOverlay()
                .onTapGesture {
                    viewModel.isShowingSonnenSettings = false
                }
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.topGrayColor, lineWidth: 8)
                .fill(bodyColor)
                .frame(width: 340, height: 180)
                .overlay {
                    VStack(spacing: 8) {
                        Group {
                            HStack {
                                Toggle("Automation", isOn: $isAutomationEnabled)
                                    .onChange(of: isAutomationEnabled) {
                                        viewModel.setSonnenAutomationEnabled(isAutomationEnabled)
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 150, height: 30, alignment: .leading)

                                Spacer()
                            }
                            .padding(.top)
                            HStack {
                                Text("Mode:")
                                    .foregroundStyle(.white)
                                Picker("", selection: $selectedMode) {
                                    ForEach(SonnenOperationModes.allCases.filter { $0 != .unknown }, id: \.self) {
                                        Text($0.title)
                                    }
                                }
                                .onChange(of: selectedMode) {
                                    viewModel.setSonnenOperationMode(selectedMode)
                                }
                                Spacer()
                            }
                            HStack {
                                Text("Watt:")
                                    .foregroundStyle(.white)
                                Picker("", selection: $selectedWatt) {
                                    ForEach(chargeValues, id: \.self) {
                                        Text("\($0)")
                                    }
                                }
                                Spacer()
                            }
                            HStack {
                                ServiceButtonView(buttonTitle: "Charge", buttonWidth: 75, buttonHeight: 40, cornerRadius: 20, action: {
                                    viewModel.charge(watt: selectedWatt)
                                })
                                ServiceButtonView(buttonTitle: "Discharge", buttonWidth: 75, buttonHeight: 40, cornerRadius: 20, action: {
                                    viewModel.charge(watt: selectedWatt)
                                })

                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                        .padding(.leading)
                        Spacer()
                    }
                }
        }
    }

    init(viewModel: ElectricityViewModel) {
        self.viewModel = viewModel
        selectedMode = viewModel.sonnenBattery.operationMode
        selectedWatt = 10000
        isAutomationEnabled = viewModel.sonnenAutomationEnabled.isActive
    }
}

#Preview {
    SonnenSettingsView(viewModel: .init(sonnenBattery: .init(entityID: .sonnenBattery), websocketService: .init()))
}
