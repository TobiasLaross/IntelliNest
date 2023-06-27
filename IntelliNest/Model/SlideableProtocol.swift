//
//  SlideableProtocol.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-25.
//

import Foundation

protocol Slideable {
    var value: Int { get }
    var isOn: Bool { get }
}

extension LightEntity: Slideable {
    var value: Int {
        isOn ? brightness : 0
    }

    var isOn: Bool {
        isActive
    }
}
