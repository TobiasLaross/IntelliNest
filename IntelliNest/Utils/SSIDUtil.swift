//
//  SSIDUtil.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-24.
//

import Foundation
import NetworkExtension

struct SSIDUtil {
    static func getCurrentSSID() async -> String? {
        guard let currentNetwork = await NEHotspotNetwork.fetchCurrent() else {
            return nil
        }

        return currentNetwork.ssid
    }
}
