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

        let exitGeofenceRegion = CLCircularRegion(center: homeCoordinates.toCLLocationCoordinate2D(),
                                                  radius: 50,
                                                  identifier: "HomeExitGeofence")
        exitGeofenceRegion.notifyOnExit = true

        let enterGeofenceRegion = CLCircularRegion(center: homeCoordinates.toCLLocationCoordinate2D(),
                                                   radius: 30,
                                                   identifier: "HomeEnterGeofence")
        enterGeofenceRegion.notifyOnEntry = true

        startMonitoring(geofenceRegion: enterGeofenceRegion)
        startMonitoring(geofenceRegion: exitGeofenceRegion)
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
            didEnterHomeAction()
            NotificationService.sendNotification(title: "Välkommen hem",
                                                 message: "",
                                                 identifier: "Geofence-did-enter-home")
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion {
            didExitHomeAction()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.error("Location manager error: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Log.error("Location manager failure: \(error)")
    }
}
