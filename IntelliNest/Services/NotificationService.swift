//
//  NotificationService.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-25.
//

import Foundation
import ShipBookSDK
import UserNotifications

class NotificationService {
    init() {}

    static func sendNotification(title: String, message: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.error("Error scheduling notification: \(error)")
            }
        }
    }
}
