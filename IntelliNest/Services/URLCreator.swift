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
                shouldRetryOnFailure = true
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
                                                            timeout: 5)
            let remoteRequest = createURLRequest(urlRequestParameters: urlRequestParameters)
            if let remoteRequest {
                do {
                    _ = try await session.data(for: remoteRequest)
                    connectionState = .internet
                    shouldRetryOnFailure = true
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
        let internalParams = URLRequestParameters(forceURLString: GlobalConstants.baseInternalUrlString,
                                                  path: apiPath,
                                                  method: .get,
                                                  timeout: 2)
        let externalParams = URLRequestParameters(forceURLString: GlobalConstants.baseExternalUrlString,
                                                  path: apiPath,
                                                  method: .get,
                                                  timeout: 5)

        guard let internalRequest = createURLRequest(urlRequestParameters: internalParams),
              let externalRequest = createURLRequest(urlRequestParameters: externalParams) else {
            connectionState = .disconnected
            return
        }

        let urlSession = session
        let result = await withTaskGroup(of: ConnectionState.self) { group -> ConnectionState in
            group.addTask {
                do {
                    _ = try await urlSession.data(for: internalRequest)
                    return .local
                } catch {
                    return .disconnected
                }
            }
            group.addTask {
                do {
                    _ = try await urlSession.data(for: externalRequest)
                    return .internet
                } catch {
                    return .disconnected
                }
            }

            for await state in group where state != .disconnected {
                group.cancelAll()
                return state
            }
            return .disconnected
        }

        connectionState = result
        if result == .disconnected {
            if shouldRetryOnFailure {
                shouldRetryOnFailure = false
                retryUpdateConnectionAfterSleep()
            }
        } else {
            shouldRetryOnFailure = true
        }
    }
}
