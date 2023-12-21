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

enum SystemImageName: String {
    case cctv = "video.fill"
    case house = "house.fill"
    case scope
    case forkKnife = "fork.knife"
    case trash = "trash.fill"
    case unlocked = "lock.open.fill"
    case locked = "lock.fill"
    case lockSlash = "lock.slash.fill"
    case clock
    case iPhone = "iphone"
    case iPhoneActive = "iphone.radiowaves.left.and.right"
    case bolt = "bolt.fill"
    case boltSlash = "bolt.slash"
    case boltCar = "bolt.car"
    case xmarkCircle = "xmark.circle"
    case powerplug
    case arrowDown = "arrow.down"
    case arrowUp = "arrow.up"
    case play = "play.fill"
    case pause = "pause.fill"
    case bedDouble = "bed.double"
    case playTV = "play.tv"
    case thermometer
    case unknown = "questionmark.circle"
}
