//
//  RoborockView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-03.
//

import SwiftUI

struct RoborockView: View {
    @ObservedObject var viewModel: RoborockViewModel

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
                                         showingMapView: $viewModel.isShowingMapView)
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
                if viewModel.isShowingrooms {
                    RoborockRoomsView(callScriptClosure: viewModel.callScript)
                } else {
                    VStack {
                        Spacer()
                            .frame(height: 120)
                        ServiceButtonView(buttonTitle: "Visa rum",
                                          icon: .init(imageName: .floorplan),
                                          action: {
                                              viewModel.isShowingrooms = true
                                          })
                    }
                }
                Spacer()
            }
            .padding(.top)
            .onAppear {
                viewModel.isShowingrooms = false
            }

            if viewModel.isShowingMapView {
                RoborockMapImageView(viewModel: viewModel)
            }
        }
    }
}

struct Roborock_Previews: PreviewProvider {
    static var previews: some View {
        RoborockView(viewModel: .init(restAPIService: PreviewProviderUtil.restAPIService))
    }
}
