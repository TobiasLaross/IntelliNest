//
//  Coordinates.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-24.
//

import CoreLocation
import Foundation

struct Coordinates: Codable, Hashable {
    let longitude: Double
    let latitude: Double

    init(longitude: Double, latitude: Double) {
        self.longitude = longitude
        self.latitude = latitude
    }

    func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
