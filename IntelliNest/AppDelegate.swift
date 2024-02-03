//
//  AppDelegate.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-20.
//

import ShipBookSDK
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let actionService = QuickActionService.shared

    func application(_ application: UIApplication,
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

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ShipBook.start(appId: GlobalConstants.secretShipBookAppID,
                       appKey: GlobalConstants.secretShipBookAppKey)
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        UserDefaults.standard.setValue(token, forKey: StorageKeys.apnsToken.rawValue)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    private let actionService = QuickActionService.shared

    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        actionService.action = QuickAction(shortcutItem: shortcutItem)
        completionHandler(true)
    }
}
