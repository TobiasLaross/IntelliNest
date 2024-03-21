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
            "Kameror"
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
        case .eniroClimateSchedule:
            "E-niro"
        case .roborock:
            "Roborock"
        case .lights:
            "Lampor"
        }
    }
}
