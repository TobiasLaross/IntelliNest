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
    weak var delegate: URLCreatorDelegate?

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

    @MainActor
    func updateConnectionState() async {
        guard connectionState != .loading else {
            return
        }
        if nextUpdate.timeIntervalSinceNow > 0 {
            return
        }

        connectionState = .loading
        nextUpdate = Date().addingTimeInterval(1)
        let urlRequestParameters = URLRequestParameters(forceURLString: GlobalConstants.baseInternalUrlString,
                                                        path: apiPath,
                                                        method: .get,
                                                        timeout: 0.8)
        let request = createURLRequest(urlRequestParameters: urlRequestParameters)
        if let request {
            do {
                _ = try await async(timeoutAfter: 0.8) {
                    return try await self.session.data(for: request)
                }
                connectionState = .local
                delegate?.baseURLChanged(urlString: GlobalConstants.baseInternalUrlString)
            } catch {
                Task {
                    await retryWithExternalURL()
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

    @MainActor
    private func retryWithExternalURL() async {
        let urlRequestParameters = URLRequestParameters(forceURLString: GlobalConstants.baseExternalUrlString,
                                                        path: apiPath,
                                                        method: .get,
                                                        timeout: 3)
        delegate?.baseURLChanged(urlString: GlobalConstants.baseExternalUrlString)
        let remoteRequest = createURLRequest(urlRequestParameters: urlRequestParameters)
        if let remoteRequest {
            do {
                (_, _) = try await session.data(for: remoteRequest)
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

    private func retryUpdateConnectionAfterSleep() {
        Task { @MainActor in
            try? await Task.sleep(seconds: 2)
            await updateConnectionState()
        }
    }

    enum TimeoutError: Error {
        case timedOut
    }

    private func async<R>(timeoutAfter maxDuration: TimeInterval,
                          do work: @escaping () async throws -> R) async throws -> R {
        return try await withThrowingTaskGroup(of: Result<R, Error>.self) { group in
            // Start actual work.
            group.addTask {
                do {
                    let result = try await work()
                    return .success(result)
                } catch {
                    return .failure(error)
                }
            }
            // Start timeout child task.
            group.addTask {
                try? await Task.sleep(seconds: maxDuration)
                return .failure(TimeoutError.timedOut)
            }
            // First finished child task wins, cancel the other task.
            guard let result = try await group.next() else {
                throw TimeoutError.timedOut
            }
            group.cancelAll()
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
    }
}
