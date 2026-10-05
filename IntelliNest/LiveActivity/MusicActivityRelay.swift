//
//  MusicActivityRelay.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import Foundation

/// Tells IntelliNest-API which Live Activity to keep current and what it shows. The relay applies Home Assistant's
/// media-player changes on top of the last state registered here and pushes them to the activity, so the activity
/// follows the music while the app is closed.
struct MusicActivityRelay {
    var baseURLString = GlobalConstants.intelliNestAPIURLString
    var session: URLSession = .shared

    private struct Registration: Encodable {
        let pushToken: String
        let deviceToken: String?
        let contentState: MusicActivityAttributes.ContentState

        enum CodingKeys: String, CodingKey {
            case pushToken = "push_token"
            case deviceToken = "device_token"
            case contentState = "content_state"
        }
    }

    private struct Unregistration: Encodable {
        let pushToken: String

        enum CodingKeys: String, CodingKey {
            case pushToken = "push_token"
        }
    }

    func register(pushToken: String, deviceToken: String?, state: MusicActivityAttributes.ContentState) async {
        // The default date strategy matches what ActivityKit decodes from a push, so the relay can hand the state
        // straight back.
        await post(path: "/live-activity/register",
                   body: Registration(pushToken: pushToken, deviceToken: deviceToken, contentState: state))
    }

    func unregister(pushToken: String) async {
        await post(path: "/live-activity/unregister", body: Unregistration(pushToken: pushToken))
    }

    private func post(path: String, body: some Encodable) async {
        guard let url = URL(string: baseURLString + path) else {
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(body)
            _ = try await session.data(for: request)
        } catch {
            // Away from home the LAN relay is unreachable; the activity then just updates while the app is open.
            Log.debug("Kunde inte nå Live Activity-reläet: \(error)")
        }
    }
}
