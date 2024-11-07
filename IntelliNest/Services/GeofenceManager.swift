//
//  GeofenceManager.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-22.
//

import CoreLocation
import Foundation
import ShipBookSDK
import UserNotifications

class GeofenceManager: NSObject {
    private let locationManager = CLLocationManager()
    private let didEnterHomeAction: VoidClosure
    private let didExitHomeAction: VoidClosure

    init(didEnterHomeAction: @escaping VoidClosure, didExitHomeAction: @escaping VoidClosure) {
        self.didEnterHomeAction = didEnterHomeAction
        self.didExitHomeAction = didExitHomeAction
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
    }

    func configureGeoFence(homeCoordinates: Coordinates) {
        for region in locationManager.monitoredRegions {
            if let circularRegion = region as? CLCircularRegion {
                locationManager.stopMonitoring(for: circularRegion)
            }
        }

        let geofenceRegion = CLCircularRegion(center: homeCoordinates.toCLLocationCoordinate2D(),
                                              radius: 50,
                                              identifier: "HomeRegion")
        geofenceRegion.notifyOnExit = true
        geofenceRegion.notifyOnEntry = true

        startMonitoring(geofenceRegion: geofenceRegion)
    }

    private func startMonitoring(geofenceRegion: CLCircularRegion) {
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            locationManager.startMonitoring(for: geofenceRegion)
        }
    }
}

extension GeofenceManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            if !UserDefaults.standard.bool(forKey: StorageKeys.isHome.rawValue) {
                UserDefaults.standard.set(true, forKey: StorageKeys.isHome.rawValue)
                didEnterHomeAction()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion {
            if UserDefaults.standard.bool(forKey: StorageKeys.isHome.rawValue) {
                UserDefaults.standard.set(false, forKey: StorageKeys.isHome.rawValue)
                didExitHomeAction()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.error("Location manager error: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Log.error("Location manager failure: \(error)")
    }
}
