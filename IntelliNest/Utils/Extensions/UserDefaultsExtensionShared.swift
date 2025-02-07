//
//  UserDefaultsExtensionShared.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-19.
//

import Foundation
import ShipBookSDK

extension UserDefaults {
    @MainActor
    static let shared: UserDefaults = {
        guard let sharedDefaults = UserDefaults(suiteName: "group.se.laross.intellinest.shared") else {
            return UserDefaults.standard
        }
        return sharedDefaults
    }()
}
