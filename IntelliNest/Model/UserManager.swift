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
    @MainActor
    static var currentUser: User {
        if let storedValue = UserDefaults.shared.string(forKey: StorageKeys.userInitials.rawValue),
           let user = User(rawValue: storedValue) {
            return user
        }

        return .unknownUser
    }

    @MainActor
    var isUserNotSet: Bool {
        UserDefaults.shared.string(forKey: StorageKeys.userInitials.rawValue) == nil
    }

    private init() {}

    func setUser(_ user: User) {
        Task { @MainActor in
            UserDefaults.shared.set(user.rawValue, forKey: StorageKeys.userInitials.rawValue)
        }
    }
}
