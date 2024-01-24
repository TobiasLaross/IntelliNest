//
//  ThermometerView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct ThermometerView: View {
    var thermometer: Entity
    var body: some View {
        VStack {
            Text(thermometer.entityId.rawValue.split(separator: "_")[1].localizedCapitalized)
                .font(.caption2)
                .foregroundColor(.white)
            Text(thermometer.state == "unavailable" ? "?" :
                "\(thermometer.state.replacingOccurrences(of: ".", with: ",")) ℃")
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.01)
        }
    }
}

struct ThermometerView_Previews: PreviewProvider {
    static var previews: some View {
        let therm = Entity(entityId: EntityId.thermGym)
        ThermometerView(thermometer: therm)
    }
}
