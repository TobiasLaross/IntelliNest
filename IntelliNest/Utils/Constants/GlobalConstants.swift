//
//  GlobalConstants.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-01.
//

import Foundation
import SwiftUI

let dashboardButtonBigTitleSize: CGFloat = 24
let dashboardButtonTitleSize: CGFloat = 14
let dashboardButtonImageSize: CGFloat = 35
let dashboardServiceButtonImageSIze: CGFloat = 20
let dashboardButtonFrameHeight: CGFloat = 90
let dashboardButtonFrameWidth: CGFloat = 90
let dashboardCircleButtonFrameSize: CGFloat = 80
let dashboardButtonCornerRadius: CGFloat = 20

enum GlobalConstants {
    static var baseExternalUrlString: String {
        if let externalUrl = Bundle.main.object(forInfoDictionaryKey: "EXTERNAL_URL") as? String {
            return "https://\(externalUrl)"
        }
        return ""
    }

    static var localSSID: String {
        if let localSSID = Bundle.main.object(forInfoDictionaryKey: "LOCAL_SSID") as? String {
            localSSID
        } else {
            ""
        }
    }

    static var secretHassToken: String {
        let hassTokenKey = "SECRET_HASS_TOKEN"
        return Bundle.main.object(forInfoDictionaryKey: hassTokenKey) as? String ?? ""
    }

    static var secretHassTokenSarah: String {
        let hassTokenKey = "SECRET_HASS_TOKEN_SARAH"
        return Bundle.main.object(forInfoDictionaryKey: hassTokenKey) as? String ?? ""
    }

    static var secretYaleAPIURL: String {
        if let yaleAPIURL = Bundle.main.object(forInfoDictionaryKey: "SECRET_YALE_API_URL") as? String {
            return "https://\(yaleAPIURL)"
        }
        return ""
    }

    static var secretYaleAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SECRET_YALE_API_KEY") as? String ?? ""
    }

    /// Spotify app Client ID (public — the app uses Authorization Code + PKCE, so
    /// no client secret is stored). Injected from the xcconfig at build time.
    static var secretSpotifyClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_ID") as? String ?? ""
    }

    static let musicAssistantConfigEntryID = "01JZ57QTQPB79NSC7GJ2VQPA8V"

    /// Music Assistant server WebSocket URL, used only for the queue commands
    /// Home Assistant exposes no REST service for: reading the full upcoming list
    /// and removing a queue item. Defaults to the internal host on Music
    /// Assistant's default port; override with the `MUSIC_ASSISTANT_WS_URL`
    /// xcconfig key if the server runs elsewhere. Queue editing therefore works
    /// on the home network only (the MA server is not exposed externally).
    static var musicAssistantWebSocketURLString: String {
        if let override = Bundle.main.object(forInfoDictionaryKey: "MUSIC_ASSISTANT_WS_URL") as? String,
           override.isNotEmpty {
            return override
        }
        return "ws://192.168.1.205:8095/ws"
    }

    static let baseInternalUrlString = "http://192.168.1.205:8123/"
    static let githubFakeUrlString = "https://192.218.223.123/"
    static var shouldUseLocalSSID: Bool {
        GlobalConstants.localSSID.isNotEmpty && GlobalConstants.localSSID != "None"
    }

    static func isGithubActionsRunning() -> Bool {
        baseExternalUrlString == githubFakeUrlString
    }
}
