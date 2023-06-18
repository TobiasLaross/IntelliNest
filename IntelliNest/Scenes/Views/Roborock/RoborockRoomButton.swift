//
//  RoborockRoomButton.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct RoborockRoomButton: View {
    let roborockRoom: EntityId
    var roomName: String
    var imageName: String
    var isSystemName: Bool = true
    var imageSize: CGFloat = 25
    var buttonWidth: CGFloat = 90
    var buttonHeight: CGFloat = 55
    var buttonCornerRadius: CGFloat = 10
    var callScriptClosure: (EntityId) -> Void

    var body: some View {
        let roomButton = ServiceButton(buttonTitle: roomName, imageName: imageName, isSystemName: isSystemName,
                                       imageSize: imageSize)
        Button {
            callScriptClosure(roborockRoom)
        } label: {
            HassButtonLabel(button: AnyView(roomButton), buttonFrameHeight: buttonHeight,
                            buttonFrameWidth: buttonWidth, buttonCornerRadius: buttonCornerRadius)
        }
    }
}

struct RoborockRoomButton_Previews: PreviewProvider {
    static var previews: some View {
        RoborockRoomButton(roborockRoom: .roborockHallway, roomName: "Name",
                           imageName: "arrow.up", callScriptClosure: { _ in })
    }
}
