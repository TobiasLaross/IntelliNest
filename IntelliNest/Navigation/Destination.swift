//
//  Destination.swift
//  IntelliNest
//
//  Created by Tobias on 2023-04-30.
//

import Foundation

enum Destination: String {
    case electricity
    case home
    case heaters
    case lynk
    case corridorHeaterDetails
    case playroomHeaterDetails
    case roborock
    case lights

    var title: String {
        switch self {
        case .electricity:
            "Ström"
        case .home:
            "Hem"
        case .heaters:
            "Värmepumpar"
        case .lynk:
            "Lynk"
        case .corridorHeaterDetails:
            "Korridoren"
        case .playroomHeaterDetails:
            "Lekrummet"
        case .roborock:
            "Roborock"
        case .lights:
            "Lampor"
        }
    }
}
