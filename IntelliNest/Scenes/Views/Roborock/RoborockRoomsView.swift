//
//  RoborockRooms.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct RoborockRoomsView: View {
    let callScriptClosure: ScriptIDClosure

    var body: some View {
        HStack(alignment: .top) {
            VStack {
                Spacer()
                    .frame(height: 50)
                DashboardButtonView(text: "Hallen",
                                    icon: .init(imageName: .hallway),
                                    iconWidth: 30,
                                    iconHeight: 30,
                                    buttonFrameWidth: 140,
                                    buttonFrameHeight: 60,
                                    action: {
                                        callScriptClosure(.roborockHallway)
                                    })
                                    .padding(.bottom, 5)
                DashboardButtonView(text: "Köket",
                                    icon: .init(systemImageName: .forkKnife),
                                    iconWidth: 20,
                                    iconHeight: 20,
                                    buttonFrameWidth: 90,
                                    buttonFrameHeight: 100,
                                    action: {
                                        callScriptClosure(.roborockKitchen)
                                    })
                                    .contextMenu {
                                        Button(action: {
                                            callScriptClosure(.roborockKitchenStove)
                                        }, label: {
                                            Text("Spisen")
                                        })
                                        Button(action: {
                                            callScriptClosure(.roborockKitchenTable)
                                        }, label: {
                                            Text("Matbordet")
                                        })
                                    }
                DashboardButtonView(text: "Tvättstugan",
                                    icon: .init(imageName: .washing),
                                    iconWidth: 20,
                                    iconHeight: 20,
                                    buttonFrameWidth: 90,
                                    buttonFrameHeight: 70,
                                    action: {
                                        callScriptClosure(.roborockLaundry)
                                    })
            }

            VStack(alignment: .trailing) {
                HStack {
                    DashboardButtonView(text: "Korridoren",
                                        icon: .init(imageName: .hallway),
                                        iconWidth: 20,
                                        iconHeight: 20,
                                        buttonFrameWidth: 80,
                                        buttonFrameHeight: 200,
                                        action: {
                                            callScriptClosure(.roborockCorridor)
                                        })
                    VStack {
                        DashboardButtonView(text: "Sovrummet",
                                            icon: .init(systemImageName: .bedDouble),
                                            iconWidth: 20,
                                            iconHeight: 20,
                                            buttonFrameWidth: 85,
                                            buttonFrameHeight: 75,
                                            action: {
                                                callScriptClosure(.roborockBedroom)
                                            })
                        DashboardButtonView(text: "Gymmet",
                                            icon: .init(imageName: .gym),
                                            iconWidth: 20,
                                            iconHeight: 20,
                                            buttonFrameWidth: 85,
                                            buttonFrameHeight: 65,
                                            action: {
                                                callScriptClosure(.roborockGym)
                                            })
                        DashboardButtonView(text: "Vince rum",
                                            icon: .init(imageName: .vince),
                                            iconWidth: 20,
                                            iconHeight: 20,
                                            buttonFrameWidth: 85,
                                            buttonFrameHeight: 75,
                                            action: {
                                                callScriptClosure(.roborockVinceRoom)
                                            })
                    }
                }

                DashboardButtonView(text: "Vardagsrummet",
                                    icon: .init(systemImageName: .playTV),
                                    iconWidth: 20,
                                    iconHeight: 20,
                                    buttonFrameWidth: 160,
                                    buttonFrameHeight: 70,
                                    action: {
                                        callScriptClosure(.roborockLivingroom)
                                    })
            }
        }
        .padding()
    }
}

struct RoborockRooms_Previews: PreviewProvider {
    static var previews: some View {
        RoborockRoomsView(callScriptClosure: { _ in })
    }
}
