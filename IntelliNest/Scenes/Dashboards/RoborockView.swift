//
//  Roborock.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-03.
//

import SwiftUI

struct RoborockView: View {
    @ObservedObject private var viewModel: RoborockViewModel

    init(viewModel: RoborockViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            VStack {
                Group {
                    Text("Status: \(viewModel.status)")
                        .font(.title2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    if viewModel.roborock.error != "" {
                        HStack {
                            Spacer()
                            Text("Error: \(viewModel.roborock.error)")
                                .bold()
                                .font(.title3)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }

                    SinceEmptiedView(emptiedAtDate: viewModel.roborockEmptiedAtDate.state,
                                     areaSinceEmpty: viewModel.roborockAreaSinceEmptied.state)
                        .padding([.top])
                    HStack {
                        RoborockInfoView(lastCleanArea: viewModel.roborockLastCleanArea.state,
                                         batteryLevel: viewModel.roborock.batteryLevel,
                                         showingMapView: $viewModel.showingMapView)
                        Spacer()
                    }

                    HStack {
                        Toggle("Automation", isOn: $viewModel.roborockAutomation.isActive)
                            .foregroundColor(.white)
                            .frame(width: 150, height: 30, alignment: .leading)
                            .onTapGesture {
                                viewModel.toggleRoborockAutomation()
                            }
                        Spacer()
                    }

                    Spacer()
                        .frame(height: 40)
                    Divider()
                }
                .padding(.leading)

                RoborockMainButtons(roborock: viewModel.roborock,
                                    toggleCleaningClosure: viewModel.toggleCleaning,
                                    dockRoborockClosure: viewModel.dockRoborock,
                                    sendRoborockToBinClosure: viewModel.sendRoborockToBin,
                                    locateRoborockClosure: viewModel.locateRoborock,
                                    manualEmptyClosure: viewModel.manualEmpty)
                Divider()
                if viewModel.showingrooms {
                    RoborockRoomsView(callScriptClosure: viewModel.callScript)
                } else {
                    VStack {
                        Spacer()
                            .frame(height: 120)
                        CircleButtonView(buttonTitle: "Visa rum",
                                         icon: .init(imageName: .floorplan),
                                         action: {
                                             viewModel.showingrooms = true
                                         })
                    }
                }
                Spacer()
            }
            .padding(.top)
            .onAppear {
                viewModel.showingrooms = false
                viewModel.appearedAction(.roborock)
            }

            if viewModel.showingMapView {
                RoborockMapImageView(viewModel: viewModel)
            }
        }
        .onTapGesture {
            viewModel.showingMapView = false
        }
    }
}

struct Roborock_Previews: PreviewProvider {
    static var previews: some View {
        RoborockView(viewModel: .init(websocketService: .init(), appearedAction: { _ in }))
    }
}
