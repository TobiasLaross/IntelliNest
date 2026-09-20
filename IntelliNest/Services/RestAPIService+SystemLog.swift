//
//  RestAPIService+SystemLog.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-20.
//

import Foundation

// MARK: - Remote logging

extension RestAPIService {
    /// Forwards a log line to Home Assistant's system log (`system_log.write`) so the
    /// app's errors and warnings show up next to HA's own logs. Failures here are
    /// swallowed on purpose: this runs from `Log.error`/`Log.warning`, so logging a
    /// failure — or showing the error banner — would recurse or spam the user.
    func reportToSystemLog(message: String, level: String) {
        let json: [JSONKey: Any] = [
            .message: message,
            .level: level,
            .logger: "intellinest"
        ]
        guard let jsonData = createJSONData(json: json) else { return }
        let path = "/api/services/\(Domain.systemLog.rawValue)/\(Action.write.rawValue)"
        Task {
            await sendSystemLogRequest(path: path, jsonData: jsonData, forceExternalURL: false)
        }
    }

    private func sendSystemLogRequest(path: String, jsonData: Data, forceExternalURL: Bool) async {
        guard let request = createURLRequest(shouldForceExternalURL: forceExternalURL,
                                             path: path,
                                             jsonData: jsonData,
                                             method: .post) else {
            return
        }

        let statusCode: Int?
        do {
            let (_, response) = try await session.data(for: request)
            statusCode = (response as? HTTPURLResponse)?.statusCode
        } catch {
            statusCode = nil
        }

        let succeeded = (statusCode ?? 500) < 300
        let url = request.url?.absoluteString ?? ""
        if !succeeded, !forceExternalURL, !url.contains(GlobalConstants.baseExternalUrlString) {
            await sendSystemLogRequest(path: path, jsonData: jsonData, forceExternalURL: true)
        }
    }
}
