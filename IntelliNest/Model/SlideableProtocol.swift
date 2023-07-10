//
//  SlideableProtocol.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-25.
//

import Foundation

protocol Slideable {
    func value(isSliding: Bool) -> Int
    var isOn: Bool { get }
    var isUpdating: Bool { get set }
}

extension LightEntity: Slideable {
    func value(isSliding: Bool) -> Int {
        if isOn || isSliding || isUpdating {
            return brightness
        }

        return 0
    }

    var isOn: Bool {
        isActive
    }
}
