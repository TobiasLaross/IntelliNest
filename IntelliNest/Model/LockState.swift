//
//  LockState.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import Foundation

enum LockState: String, Decodable {
    case locked
    case locking
    case unlocked
    case unlocking
    case unknown
}
