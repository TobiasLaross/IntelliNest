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

    static var secretShipBookAppID: String {
        Bundle.main.object(forInfoDictionaryKey: "SECRET_SHIP_BOOK_APP_ID") as? String ?? ""
    }

    static var secretShipBookAppKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SECRET_SHIP_BOOK_APP_KEY") as? String ?? ""
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

    static var secretRTSPURLBackCamera: String {
        if let rtspURL = Bundle.main.object(forInfoDictionaryKey: "SECRET_RTSP_STREAM_CAMERA_BACK") as? String {
            return "rtsp://\(rtspURL)"
        }
        return ""
    }

    static var secretRTSPURLFrontCamera: String {
        if let rtspURL = Bundle.main.object(forInfoDictionaryKey: "SECRET_RTSP_STREAM_CAMERA_FRONT") as? String {
            return "rtsp://\(rtspURL)"
        }
        return ""
    }

    static var secretRTSPURLCarportkCamera: String {
        if let rtspURL = Bundle.main.object(forInfoDictionaryKey: "SECRET_RTSP_STREAM_CAMERA_CARPORT") as? String {
            return "rtsp://\(rtspURL)"
        }
        return ""
    }

    static var secretRTSPURLVinceCamera: String {
        if let rtspURL = Bundle.main.object(forInfoDictionaryKey: "SECRET_RTSP_STREAM_CAMERA_VINCE") as? String {
            return "rtsp://\(rtspURL)"
        }
        return ""
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
