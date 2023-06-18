//
//  RoborockMainButtons.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct RoborockMainButtons: View {
    @Binding var roborock: RoborockEntity
    let toggleCleaningClosure: VoidClosure
    let dockRoborockClosure: VoidClosure
    let sendRoborockToBinClosure: VoidClosure
    let locateRoborockClosure: VoidClosure
    let manualEmptyClosure: VoidClosure

    var body: some View {
        let playPausButton = SwitchButton(entity: $roborock, buttonTitle: "Dammsug",
                                          activeImageName: "pause.fill", defaultImageName: "play.fill")
        let dockButton = ServiceButton(buttonTitle: "Docka", imageName: "house.fill")
        let locateButton = ServiceButton(buttonTitle: "Hitta", imageName: "scope")
        let sendToBinButton = ServiceButton(buttonTitle: "Töm", imageName: "trash.fill")
        let buttonHeight: CGFloat = 70
        let buttonWidth: CGFloat = 80

        HStack {
            Button {
                toggleCleaningClosure()
            } label: {
                HassButtonLabel(button: AnyView(playPausButton), buttonFrameHeight: buttonHeight,
                                buttonFrameWidth: buttonWidth)
            }

            Button {
                dockRoborockClosure()
            } label: {
                HassButtonLabel(button: AnyView(dockButton), buttonFrameHeight: buttonHeight,
                                buttonFrameWidth: buttonWidth)
            }

            Button {
                locateRoborockClosure()
            } label: {
                HassButtonLabel(button: AnyView(locateButton), buttonFrameHeight: buttonHeight,
                                buttonFrameWidth: buttonWidth)
            }

            Button {
                sendRoborockToBinClosure()
            } label: {
                HassButtonLabel(button: AnyView(sendToBinButton), buttonFrameHeight: buttonHeight,
                                buttonFrameWidth: buttonWidth)
            }
            .contextMenu {
                Button(action: manualEmptyClosure, label: {
                    Text("Manuell tömning")
                })
            }
        }
    }
}

struct RoborockMainButtons_Previews: PreviewProvider {
    static var previews: some View {
        RoborockMainButtons(
            roborock: .constant(.init(entityId: .roborock, state: "")),
            toggleCleaningClosure: {},
            dockRoborockClosure: {},
            sendRoborockToBinClosure: {},
            locateRoborockClosure: {},
            manualEmptyClosure: {})
    }
}
