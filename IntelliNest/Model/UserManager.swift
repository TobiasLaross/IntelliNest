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

    var name: String {
        switch self {
        case .sarah:
            return "Sarah"
        case .tobias:
            return "Tobias"
        case .guest:
            return "Gäst"
        }
    }
}

/// User identifier is used in loggin but could potentially be used for personalizing the controls
/// Example: kid or guest mode
struct UserManager {
    static let shared = UserManager()
    static let storageKey = "userInitials"
    static var currentUser: User {
        guard let storedValue = UserDefaults.standard.string(forKey: UserManager.storageKey),
              let user = User(rawValue: storedValue) else {
            return .guest
        }
        return user
    }

    var isUserNotSet: Bool {
        UserDefaults.standard.string(forKey: UserManager.storageKey) == nil
    }

    private init() {}

    func setUser(_ user: User) {
        UserDefaults.standard.set(user.rawValue, forKey: UserManager.storageKey)
    }
}
