//
//  RoborockMainButtons.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct RoborockMainButtons: View {
    var roborock: RoborockEntity
    let toggleCleaningClosure: VoidClosure
    let dockRoborockClosure: VoidClosure
    let sendRoborockToBinClosure: VoidClosure
    let locateRoborockClosure: VoidClosure
    let manualEmptyClosure: VoidClosure

    var body: some View {
        HStack {
            Group {
                CircleButtonView(buttonTitle: "Dammsug",
                                 isActive: roborock.isActive,
                                 icon: roborock.icon,
                                 iconHeight: 25,
                                 action: toggleCleaningClosure)
                CircleButtonView(buttonTitle: "Docka",
                                 icon: .init(systemImageName: .house),
                                 imageSize: 25,
                                 action: dockRoborockClosure)
                CircleButtonView(buttonTitle: "Hitta",
                                 icon: .init(systemImageName: .scope),
                                 imageSize: 25,
                                 action: locateRoborockClosure)
                CircleButtonView(buttonTitle: "Töm",
                                 icon: .init(systemImageName: .trash),
                                 imageSize: 25,
                                 action: sendRoborockToBinClosure)
                    .contextMenu {
                        Button(action: manualEmptyClosure, label: {
                            Text("Manuell tömning")
                        })
                    }
            }
        }
    }
}

struct RoborockMainButtons_Previews: PreviewProvider {
    static var previews: some View {
        RoborockMainButtons(
            roborock: .init(entityId: .roborock, state: ""),
            toggleCleaningClosure: {},
            dockRoborockClosure: {},
            sendRoborockToBinClosure: {},
            locateRoborockClosure: {},
            manualEmptyClosure: {})
    }
}
