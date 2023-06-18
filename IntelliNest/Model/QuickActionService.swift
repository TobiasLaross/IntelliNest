//
//  Action.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-20.
//

import UIKit

// 1
enum QuickActionType: String {
    case carHeater
}

// 2
enum QuickAction: Equatable {
    case carheater

    // 3
    init?(shortcutItem: UIApplicationShortcutItem) {
        // 4
        guard let type = QuickActionType(rawValue: shortcutItem.type) else {
            return nil
        }

        // 5
        switch type {
        case .carHeater:
            self = .carheater
        }
    }
}

// 6
class QuickActionService: ObservableObject {
    static let shared = QuickActionService()

    // 7
    @Published var action: QuickAction?
}
