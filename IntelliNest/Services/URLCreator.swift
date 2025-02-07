//
//  URLCreator.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-01.
//

import Foundation
import ShipBookSDK

enum ConnectionState {
    case local
    case internet
    case disconnected
    case unset
    case loading
}

@MainActor
class URLCreator: ObservableObject, URLRequestBuilder {
    @Published var connectionState = ConnectionState.unset
    var nextUpdate = Date().addingTimeInterval(-1)
    var urlString: String {
        connectionState == .local ? GlobalConstants.baseInternalUrlString : GlobalConstants.baseExternalUrlString
    }

    private let apiPath = "/api"
    private var shouldRetryOnFailure = true

    private let session: URLSession
    init(session: URLSession = .shared) {
        self.session = session
    }

    func updateConnectionState(ignoreLocalSSID: Bool = false) async {
        guard connectionState != .loading else {
            return
        }
        if nextUpdate.timeIntervalSinceNow > 0 {
            return
        }

        connectionState = .loading
        nextUpdate = Date().addingTimeInterval(1)

        if GlobalConstants.shouldUseLocalSSID && !ignoreLocalSSID {
            let ssid = await SSIDUtil.getCurrentSSID()
            if ssid == GlobalConstants.localSSID {
                connectionState = .local
            } else {
                retryWithExternalURL()
            }
        } else {
            await updateConnectionStateUsingRequest()
        }
    }

    func getRequestHeaders() -> [String: String] {
        let token = UserManager.currentUser == .sarah ? GlobalConstants.secretHassTokenSarah : GlobalConstants.secretHassToken
        return [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": "Bearer \(token)"
        ]
    }

    private func retryWithExternalURL() {
        Task { @MainActor in
            let urlRequestParameters = URLRequestParameters(forceURLString: GlobalConstants.baseExternalUrlString,
                                                            path: apiPath,
                                                            method: .get,
                                                            timeout: 3)
            let remoteRequest = createURLRequest(urlRequestParameters: urlRequestParameters)
            if let remoteRequest {
                do {
                    _ = try await session.data(for: remoteRequest)
                    connectionState = .internet
                } catch {
                    connectionState = .disconnected
                    if shouldRetryOnFailure {
                        shouldRetryOnFailure = false
                        retryUpdateConnectionAfterSleep()
                    }
                }
            }
        }
    }

    private func retryUpdateConnectionAfterSleep() {
        Task { @MainActor in
            try? await Task.sleep(seconds: 2)
            await updateConnectionState()
        }
    }

    @MainActor
    private func updateConnectionStateUsingRequest() async {
        let urlRequestParameters = URLRequestParameters(forceURLString: GlobalConstants.baseInternalUrlString,
                                                        path: apiPath,
                                                        method: .get,
                                                        timeout: 0.8)
        let request = createURLRequest(urlRequestParameters: urlRequestParameters)
        if let request {
            do {
                _ = try await session.data(for: request)
                connectionState = .local
            } catch {
                retryWithExternalURL()
            }
        }
    }
}
