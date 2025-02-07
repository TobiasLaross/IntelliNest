//
//  AppDelegate.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-20.
//

import ShipBookSDK
import UIKit

private enum CategoryIdentifier: String {
    case washerReminder
}

enum NotificationActionIdentifier: String {
    case snoozeWashingMachine
    case startCarHeater = "start-car-heater"
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let actionService = QuickActionService.shared

    func application(_: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            actionService.action = QuickAction(shortcutItem: shortcutItem)
        }

        let configuration = UISceneConfiguration(name: connectingSceneSession.configuration.name,
                                                 sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(_: UIApplication,
                     didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Task {
            ShipBook.start(appId: GlobalConstants.secretShipBookAppID,
                           appKey: GlobalConstants.secretShipBookAppKey)
            UNUserNotificationCenter.current().delegate = self
            let action = UNNotificationAction(identifier: NotificationActionIdentifier.snoozeWashingMachine.rawValue,
                                              title: "Snooza Tvättmaskinen",
                                              options: [.foreground])
            let category = UNNotificationCategory(identifier: CategoryIdentifier.washerReminder.rawValue,
                                                  actions: [action],
                                                  intentIdentifiers: [],
                                                  options: [])
            UNUserNotificationCenter.current().setNotificationCategories([category])
            setupRemoteNotifications()
        }
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.categoryIdentifier == CategoryIdentifier.washerReminder.rawValue &&
            response.actionIdentifier == NotificationActionIdentifier.snoozeWashingMachine.rawValue {
            if let deepLinkURL = URL(string: "IntelliNest://\(response.actionIdentifier)") {
                DispatchQueue.main.async {
                    UIApplication.shared.open(deepLinkURL)
                }
            }
        }
        completionHandler()
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        NotificationCenter.default.post(name: Notification.Name("UpdatedAPNSToken"),
                                        object: nil,
                                        userInfo: ["apnsToken": token])
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

private extension AppDelegate {
    func setupRemoteNotifications() {
        Task { @MainActor in
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert])
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                UNUserNotificationCenter.current().delegate = self
            } catch {
                Log.error("Failed to requestAuthorization for push, \(error.localizedDescription)")
            }
        }
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    private let actionService = QuickActionService.shared

    func windowScene(_: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        actionService.action = QuickAction(shortcutItem: shortcutItem)
        completionHandler(true)
    }
}
