//
//  Heater.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-23.
//

import Foundation

enum HvacMode: String {
    case off
    case heat
    case cool
}

enum FanMode: String, Decodable {
    case auto
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
}

enum HorizontalMode: String, Decodable {
    case auto
    case oneLeft = "1_left"
    case two = "2"
    case three = "3"
    case four = "4"
    case fiveRight = "5_right"
    case swing
    case split
    case unknown
}

enum HeaterVerticalPosition: String, Decodable {
    case auto
    case highest = "1_up"
    case position2 = "2"
    case position3 = "3"
    case position4 = "4"
    case lowest = "5_down"
    case swing
    case unknown
}
