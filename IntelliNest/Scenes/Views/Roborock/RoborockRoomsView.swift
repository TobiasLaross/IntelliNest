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
                RoborockRoomButton(roborockRoom: .roborockHallway,
                                   roomName: "Hallen",
                                   imageName: "hallway",
                                   isSystemName: false,
                                   buttonWidth: 140,
                                   callScriptClosure: callScriptClosure)
                    .padding(.bottom, 5)
                RoborockRoomButton(roborockRoom: .roborockKitchen,
                                   roomName: "Köket",
                                   imageName: "fork.knife",
                                   buttonWidth: 90,
                                   buttonHeight: 120,
                                   callScriptClosure: callScriptClosure)
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

                RoborockRoomButton(roborockRoom: .roborockLaundry,
                                   roomName: "Tvättstugan",
                                   imageName: "washing",
                                   isSystemName: false,
                                   buttonWidth: 90,
                                   buttonHeight: 70,
                                   callScriptClosure: callScriptClosure)
            }

            VStack(alignment: .trailing) {
                HStack {
                    RoborockRoomButton(roborockRoom: .roborockCorridor,
                                       roomName: "Korridoren",
                                       imageName: "hallway",
                                       isSystemName: false,
                                       buttonHeight: 200,
                                       callScriptClosure: callScriptClosure)
                    VStack {
                        RoborockRoomButton(roborockRoom: .roborockBedroom,
                                           roomName: "Sovrummet",
                                           imageName: "bed.double",
                                           callScriptClosure: callScriptClosure)
                        RoborockRoomButton(roborockRoom: .roborockGym,
                                           roomName: "Gymmet",
                                           imageName: "gym",
                                           isSystemName: false,
                                           callScriptClosure: callScriptClosure)
                        RoborockRoomButton(roborockRoom: .roborockVinceRoom,
                                           roomName: "Vince rum",
                                           imageName: "vince",
                                           isSystemName: false,
                                           callScriptClosure: callScriptClosure)
                    }
                }

                RoborockRoomButton(roborockRoom: .roborockLivingroom,
                                   roomName: "Vardagsrummet",
                                   imageName: "play.tv",
                                   buttonWidth: 160,
                                   buttonHeight: 70,
                                   callScriptClosure: callScriptClosure)
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
