//
//  ImageExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-19.
//

import Foundation
import SwiftUI

extension Image {
    init(imageName: ImageName) {
        self.init(imageName.rawValue)
    }

    init(systemImageName: SystemImageName) {
        self.init(systemName: systemImageName.rawValue)
    }
}

enum ImageName: String {
    case aircondition
    case defrost = "defrost.filled"
    case evPlugType2 = "ev-plug-type2"
    case evPlugCCS2 = "ev-plug-ccs2"
    case floorplan
    case gym
    case hallway
    case powerGrid = "powergrid"
    case refresh
    case settings
    case solarPanel = "solarpanel"
    case seatHeater = "seatheater.filled"
    case vince
    case washing
}

// SF Symbols
enum SystemImageName: String {
    case arrowDown = "arrow.down"
    case arrowUp = "arrow.up"
    case bedDouble = "bed.double"
    case bolt = "bolt.fill"
    case boltSlash = "bolt.slash"
    case boltCar = "bolt.car"
    case cctv = "video.fill"
    case clock
    case engineFilled = "engine.combustion.fill"
    case forkKnife = "fork.knife"
    case house = "house.fill"
    case iPhone = "iphone"
    case iPhoneActive = "iphone.radiowaves.left.and.right"
    case locked = "lock.fill"
    case lockSlash = "lock.slash.fill"
    case pause = "pause.fill"
    case pills = "pills.fill"
    case play = "play.fill"
    case playTV = "play.tv"
    case powerplug
    case scope
    case thermometer
    case headLightBeam = "headlight.high.beam"
    case lightbulbSlash = "lightbulb.slash"
    case trash = "trash.fill"
    case unknown = "questionmark.circle"
    case unlocked = "lock.open.fill"
    case xmarkCircle = "xmark.circle"
}
