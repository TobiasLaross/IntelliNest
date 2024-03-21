//
//  UserManager.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-18.
//

import Foundation

enum User: String, CaseIterable {
    case sarah = "SL"
    case tobias = "TL"
    case guest = "Guest"
    case unknownUser = "Unknown User"

    var name: String {
        switch self {
        case .sarah:
            "Sarah"
        case .tobias:
            "Tobias"
        case .guest:
            "Gäst"
        case .unknownUser:
            "Unknown User"
        }
    }
}

struct UserManager {
    static let shared = UserManager()
    static var currentUser: User {
        if let storedValue = UserDefaults.shared.string(forKey: StorageKeys.userInitials.rawValue),
           let user = User(rawValue: storedValue) {
            return user
        }

        return .unknownUser
    }

    var isUserNotSet: Bool {
        UserDefaults.shared.string(forKey: StorageKeys.userInitials.rawValue) == nil
    }

    private init() {}

    func setUser(_ user: User) {
        UserDefaults.shared.set(user.rawValue, forKey: StorageKeys.userInitials.rawValue)
    }
}
