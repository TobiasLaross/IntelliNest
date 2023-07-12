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
                    Text("Status: \(viewModel.getStatus())")
                        .font(.title2)
                        .multilineTextAlignment(.center)

                    if viewModel.roborock.error != "" {
                        HStack {
                            Spacer()
                            Text("Error: \(viewModel.roborock.error)")
                                .bold()
                                .font(.title3)
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

                RoborockMainButtons(roborock: $viewModel.roborock,
                                    toggleCleaningClosure: viewModel.toggleCleaning,
                                    dockRoborockClosure: viewModel.dockRoborock,
                                    sendRoborockToBinClosure: viewModel.sendRoborockToBin,
                                    locateRoborockClosure: viewModel.locateRoborock,
                                    manualEmptyClosure: viewModel.manualEmpty)
                Divider()
                RoborockRoomsView(callScriptClosure: viewModel.callScript)
                Spacer()
            }
            .padding(.top)
            .onAppear {
                viewModel.appearedAction(.roborock)
            }

            if viewModel.showingMapView {
                RoborockMapImageView(baseURLString: viewModel.baseURLString)
            }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onEnded { _ in
                    self.viewModel.showingMapView = false
                }
        )
    }
}

struct Roborock_Previews: PreviewProvider {
    static var previews: some View {
        RoborockView(viewModel: .init(websocketService: .init(), appearedAction: { _ in }))
    }
}
