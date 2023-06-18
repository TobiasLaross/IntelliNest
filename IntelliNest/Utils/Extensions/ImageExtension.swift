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
    case evPlugType2 = "ev-plug-type2"
    case evPlugCCS2 = "ev-plug-ccs2"
    case refresh
    case settings
}

enum SystemImageName: String {
    case unlocked = "lock.open.fill"
    case locked = "lock.fill"
    case lockSlash = "lock.slash.fill"
    case clock
    case iPhone = "iphone"
    case iPhoneActive = "iphone.radiowaves.left.and.right"
}
