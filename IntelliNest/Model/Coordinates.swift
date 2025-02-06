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

    func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
