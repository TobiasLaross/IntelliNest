//
//  Destination.swift
//  IntelliNest
//
//  Created by Tobias on 2023-04-30.
//

import Foundation

enum Destination: String {
    case cameras
    case electricity
    case home
    case heaters
    case lynk
    case corridorHeaterDetails
    case playroomHeaterDetails
    case eniroClimateSchedule
    case roborock
    case lights

    var title: String {
        switch self {
        case .cameras:
            return "Kameror"
        case .electricity:
            return "Ström"
        case .home:
            return "Hem"
        case .heaters:
            return "Värmepumpar"
        case .lynk:
            return "Lynk"
        case .corridorHeaterDetails:
            return "Korridoren"
        case .playroomHeaterDetails:
            return "Lekrummet"
        case .eniroClimateSchedule:
            return "E-niro"
        case .roborock:
            return "Roborock"
        case .lights:
            return "Lampor"
        }
    }
}
