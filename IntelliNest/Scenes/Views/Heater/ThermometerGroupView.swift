//
//  ThermometerGroupView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct ThermometerGroupView: View {
    var therm1: Entity
    var therm2: Entity
    var therm3: Entity
    var therm4: Entity

    var body: some View {
        HStack {
            ThermometerView(thermometer: therm1)
            ThermometerView(thermometer: therm2)
                .padding(.leading)
            ThermometerView(thermometer: therm3)
                .padding(.horizontal)
            ThermometerView(thermometer: therm4)
        }
        .background(bodyColor)
    }
}

struct ThermometerGroupView_Previews: PreviewProvider {
    static var previews: some View {
        let therm = Entity(entityId: EntityId.thermGym)
        ThermometerGroupView(therm1: therm, therm2: therm, therm3: therm, therm4: therm)
    }
}
