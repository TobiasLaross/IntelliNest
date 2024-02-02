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
            Text(thermometer.entityId.roomTitle)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
            Text(thermometer.state == "unavailable" ? "?" :
                "\(thermometer.state.replacingOccurrences(of: ".", with: ",")) ℃")
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.01)
        }
    }
}

private extension EntityId {
    var roomTitle: String {
        switch self {
        case .thermCorridor:
            return "Korridoren"
        case .thermBedroom:
            return "Sovrummet"
        case .thermVince:
            return "Vince rum"
        case .thermGym:
            return "Gymmet"
        case .thermPlayroom:
            return "Lekrummet"
        case .thermCommonarea:
            return "Vardagsrummet"
        case .thermGuest:
            return "Gästrummet"
        case .thermKitchen:
            return "Köket"
        default:
            return "Missing room"
        }
    }
}

struct ThermometerView_Previews: PreviewProvider {
    static var previews: some View {
        let therm = Entity(entityId: EntityId.thermGym)
        ThermometerView(thermometer: therm)
    }
}
