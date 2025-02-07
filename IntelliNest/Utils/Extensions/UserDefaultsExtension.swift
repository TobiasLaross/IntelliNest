//
//  UserDefaultsExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-24.
//

import Foundation
import ShipBookSDK

extension UserDefaults {
    @MainActor
    func setCoordinates(_ coordinates: Coordinates, forKey key: StorageKeys) {
        do {
            let encodedData = try JSONEncoder().encode(coordinates)
            set(encodedData, forKey: key.rawValue)
        } catch {
            Log.error("Failed to encode coordinates: \(error)")
        }
    }

    func coordinates(forKey key: String) -> Coordinates? {
        guard let data = data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(Coordinates.self, from: data)
    }
}
