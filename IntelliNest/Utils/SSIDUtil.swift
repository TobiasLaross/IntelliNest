//
//  SSIDUtil.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-24.
//

import CoreLocation
import Foundation
import ShipBookSDK
import SystemConfiguration.CaptiveNetwork

class SSIDUtil {
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

    private static let locationManager = CLLocationManager()
    private static let locationManagerDelegate = LocationManagerDelegate()

    static func fetchSSID() async -> String? {
        let isAuthorized = await requestLocationPermission()
        return isAuthorized ? getCurrentSSID() : nil
    }

    private static func requestLocationPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
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

    private static func getCurrentSSID() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for interface in interfaces {
            guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? else { continue }
            return interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
        }
        return nil
    }
}
