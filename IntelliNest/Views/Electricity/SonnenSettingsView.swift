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

    let chargeValues = [0, 1000, 3000, 5000, 7000, 10000]

    var body: some View {
        ZStack {
            FullScreenBackgroundOverlay()
                .onTapGesture {
                    viewModel.isShowingSonnenSettings = false
                }
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primaryContentBackground)
                .frame(width: 380, height: 230)
                .overlay {
                    VStack(alignment: .leading) {
                        Group {
                            HStack {
                                Toggle("Automation", isOn: $isAutomationEnabled)
                                    .onChange(of: isAutomationEnabled) {
                                        viewModel.setSonnenAutomationEnabled(isAutomationEnabled)
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 170, height: 30, alignment: .leading)
                            }
                            .padding(.top)
                            HStack {
                                INText("Mode:")
                                Picker("", selection: $selectedMode) {
                                    ForEach(SonnenOperationModes.allCases.filter { $0 != .unknown }, id: \.self) {
                                        Text($0.title)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                                .onChange(of: selectedMode) {
                                    viewModel.setSonnenOperationMode(selectedMode)
                                }
                            }
                            HStack {
                                INText("Watt:")
                                Picker("", selection: $selectedWatt) {
                                    ForEach(chargeValues, id: \.self) {
                                        Text("\($0)")
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            HStack {
                                ServiceButtonView(buttonTitle: "Charge", buttonWidth: 75, buttonHeight: 40, cornerRadius: 20, action: {
                                    viewModel.charge(watt: selectedWatt)
                                })
                                ServiceButtonView(buttonTitle: "Discharge", buttonWidth: 75, buttonHeight: 40, cornerRadius: 20, action: {
                                    viewModel.discharge(watt: selectedWatt)
                                })
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
    SonnenSettingsView(viewModel: PreviewProviderUtil.electricityViewModel)
}
