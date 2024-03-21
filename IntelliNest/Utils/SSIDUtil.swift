//
//  SSIDUtil.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-24.
//

import CoreLocation
import Foundation
import NetworkExtension
import ShipBookSDK
import SystemConfiguration.CaptiveNetwork

struct SSIDUtil {
    private static let locationManager = CLLocationManager()
    private static let locationManagerDelegate = LocationManagerDelegate()
    private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
        var permissionHandler: ((Bool) -> Void)?

        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                permissionHandler?(true)
            default:
                permissionHandler?(false)
            }
        }
    }

    static func getCurrentSSID() async -> String? {
        let isAuthorized = await requestLocationPermission()
        guard isAuthorized, let currentNetwork = await NEHotspotNetwork.fetchCurrent() else {
            return nil
        }
        return currentNetwork.ssid
    }

    private static func requestLocationPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            locationManager.delegate = locationManagerDelegate

            let status = locationManager.authorizationStatus
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                continuation.resume(returning: true)
            case .notDetermined:
                locationManagerDelegate.permissionHandler = { granted in
                    continuation.resume(returning: granted)
                }
                locationManager.requestAlwaysAuthorization()
            default:
                continuation.resume(returning: false)
            }
        }
    }
}
