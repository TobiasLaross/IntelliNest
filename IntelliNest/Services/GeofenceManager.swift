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

    func configureGeoFence(homeCoordinates: Coordinates, oldCoordinates: Coordinates? = nil) {
        if let oldCoordinates {
            let oldGeofenceRegion = CLCircularRegion(center: oldCoordinates.toCLLocationCoordinate2D(),
                                                     radius: 35,
                                                     identifier: "HouseGeofence")
            locationManager.stopMonitoring(for: oldGeofenceRegion)
        }

        let geofenceRegion = CLCircularRegion(center: homeCoordinates.toCLLocationCoordinate2D(),
                                              radius: 35,
                                              identifier: "HouseGeofence")
        geofenceRegion.notifyOnEntry = true
        geofenceRegion.notifyOnExit = true
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
