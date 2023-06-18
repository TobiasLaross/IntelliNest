//
//  File.swift
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

class URLCreator: ObservableObject, URLRequestBuilder {
    @Published var connectionState = ConnectionState.unset

    var nextUpdate = Date().addingTimeInterval(-1)
    var urlString: String {
        connectionState == .local ? GlobalConstants.baseInternalUrlString : GlobalConstants.baseExternalUrlString
    }

    private let counterPath = "/api/states/counter.test88338833"
    private var shouldRetryOnFailure = true

    private let session: URLSession
    init(session: URLSession = .shared) {
        self.session = session
    }

    @MainActor
    func updateConnectionState() async {
        if nextUpdate.timeIntervalSinceNow > 0 {
            return
        }

        connectionState = .loading
        nextUpdate = Date().addingTimeInterval(3)
        var urlRequestParameters = URLRequestParameters(forceURLString: GlobalConstants.baseInternalUrlString,
                                                        path: counterPath,
                                                        method: .get,
                                                        timeout: 0.8)
        let request = createURLRequest(urlRequestParameters: urlRequestParameters)
        if let request {
            do {
                let (_, _) = try await session.data(for: request)
                connectionState = .local
            } catch {
                urlRequestParameters.forceURLString = GlobalConstants.baseExternalUrlString
                urlRequestParameters.timeout = 4
                let remoteRequest = createURLRequest(urlRequestParameters: urlRequestParameters)
                if let remoteRequest {
                    do {
                        (_, _) = try await session.data(for: remoteRequest)
                        connectionState = .internet
                    } catch {
                        connectionState = .disconnected
                        if shouldRetryOnFailure {
                            shouldRetryOnFailure = false
                            retryAfterSleep()
                        }
                    }
                }
            }
        }
    }

    func getRequestHeaders() -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": "Bearer \(GlobalConstants.secretHassToken)"
        ]
    }

    private func retryAfterSleep() {
        Task { @MainActor in
            try? await Task.sleep(seconds: 2)
            await updateConnectionState()
        }
    }
}
