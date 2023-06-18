//
//  YaleAccessService.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import Foundation
import Security
import ShipBookSDK

class YaleApiService: URLRequestBuilder {
    private let hassApiService: HassApiService
    private let session: URLSession
    private var accessToken = ""
    private var recentlyUpdatedRemoteAccessToken = false
    let urlString = GlobalConstants.secretYaleAPIURL

    init(hassApiService: HassApiService, session: URLSession = .shared) {
        self.hassApiService = hassApiService
        self.session = session
        if let accessToken = getAccessToken(), !willAccessTokenExpireSoon(accessToken: accessToken) {
            self.accessToken = accessToken
        } else {
            fetchRemoteAccessToken()
        }
    }

    func getLockState(lockID: LockID) async throws -> LockState {
        let path = "/locks/\(lockID.rawValue)"
        guard let request = createURLRequest(path: path, method: .get) else {
            throw EntityError.badRequest
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EntityError.badResponse
        }
        guard httpResponse.statusCode <= 299 else {
            Log.error("Failed request with status: \(httpResponse.statusCode) and body:\n \(String(data: data, encoding: .utf8) ?? "")")
            throw EntityError.httpRequestFailure
        }
        if willAccessTokenExpireSoon(accessToken: accessToken),
           let accessToken = httpResponse.allHeaderFields["x-august-access-token"] as? String {
            updateLocalAccessToken(newAccessToken: accessToken)
            updateRemoteAccessToken(newAccessToken: accessToken)
        }
        let decoder = JSONDecoder()
        let yaleLockResponse = try decoder.decode(YaleLockResponse.self, from: data)
        return LockState(rawValue: yaleLockResponse.lockStatus.status) ?? .unknown
    }

    func setLockState(lockID: LockID, action: Action) async -> Bool {
        let path = "/remoteoperate/\(lockID.rawValue)/\(action.rawValue)"
        guard let request = createURLRequest(path: path, method: .put) else {
            Log.error("Failed to create request for path: \(path)")
            return false
        }
        do {
            let (body, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                Log.error("Failed to get response as HTTPURLResponse")
                return false
            }
            if [200, 202].contains(httpResponse.statusCode) {
                return true
            }
            logRequestError(path: path, status: httpResponse.statusCode, body: body)
            return false
        } catch {
            Log.error("Request failed with error: \(error)")
            return false
        }
    }

    func getRequestHeaders() -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "x-august-access-token": "\(accessToken)",
            "x-kease-api-key": "\(GlobalConstants.secretYaleAPIKey)"
        ]
    }

    private func willAccessTokenExpireSoon(accessToken: String) -> Bool {
        let calendar = Calendar.current
        let dateOneMonthFromNow = calendar.date(byAdding: .month, value: 1, to: Date())

        if let expDate = jwtExpireTime(jwtToken: accessToken) {
            if let dateOneMonthFromNow, expDate < dateOneMonthFromNow {
                return true
            }
        } else {
            Log.warning("Could not determine Yale access token expiration date")
        }
        return false
    }

    private func getAccessToken() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: StorageKeys.yaleAccessToken.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: kCFBooleanTrue!]

        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data,
               let accessToken = String(data: retrievedData, encoding: .utf8) {
                return accessToken
            }
        }

        Log.warning("Missing access token, retrieving from backend")
        return nil
    }

    private func fetchRemoteAccessToken() {
        Task {
            do {
                async let part1 = hassApiService.get(entityId: .yaleAccessTokenPart1, entityType: Entity.self)
                async let part2 = hassApiService.get(entityId: .yaleAccessTokenPart2, entityType: Entity.self)
                async let part3 = hassApiService.get(entityId: .yaleAccessTokenPart3, entityType: Entity.self)
                async let part4 = hassApiService.get(entityId: .yaleAccessTokenPart4, entityType: Entity.self)
                async let part5 = hassApiService.get(entityId: .yaleAccessTokenPart5, entityType: Entity.self)

                let parts = try await [part1, part2, part3, part4, part5]
                accessToken = parts.map { $0.state }.joined()
                updateLocalAccessToken(newAccessToken: accessToken)
            } catch {
                Log.error("Failed to fetch access token \(error)")
            }
        }
    }

    private func jwtExpireTime(jwtToken: String) -> Date? {
        let jwtParts = jwtToken.components(separatedBy: ".")
        if jwtParts.count > 1 {
            let base64Payload = base64UrlToBase64(base64Url: jwtParts[1])
            if let jwtPayloadData = Data(base64Encoded: base64Payload) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: jwtPayloadData, options: []) as? [String: Any] {
                        if let expTimestamp = json["exp"] as? TimeInterval {
                            return Date(timeIntervalSince1970: expTimestamp)
                        }
                    }
                } catch {
                    Log.warning("Failed to decode JWT: \(error)")
                }
            }
        }
        return nil
    }

    private func base64UrlToBase64(base64Url: String) -> String {
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        return base64
    }

    private func logRequestError(path: String, status: Int, body: Data) {
        let bodyText = String(data: body, encoding: .utf8) ?? ""
        Log.error("Failed request: \(path), Status: \(status), Body: \(bodyText)")
    }

    private func updateLocalAccessToken(newAccessToken: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: StorageKeys.yaleAccessToken.rawValue]

        guard let accessTokenData = newAccessToken.data(using: .utf8) else {
            Log.error("Could not get utf8 data from accessToken")
            return
        }
        let attributesToUpdate: [String: Any] = [kSecValueData as String: accessTokenData]
        var status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if status == errSecItemNotFound {
            // The token doesn't exist, add it to the keychain
            let newQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                           kSecAttrAccount as String: StorageKeys.yaleAccessToken.rawValue,
                                           kSecValueData as String: accessTokenData]

            status = SecItemAdd(newQuery as CFDictionary, nil)
        }
        if status != errSecSuccess {
            Log.error("Failed to add item to keychain")
        }
    }

    private func updateRemoteAccessToken(newAccessToken: String) {
        guard !recentlyUpdatedRemoteAccessToken else {
            return
        }
        recentlyUpdatedRemoteAccessToken = true
        Task { @MainActor in
            let path = "/api/services/script/update_yale_access_token"
            var json = [JSONKey: Any]()
            json[JSONKey.yaleAccessTokenFull] = newAccessToken
            let jsonData = createJSONData(json: json)

            guard let request = hassApiService.createURLRequest(path: path,
                                                                jsonData: jsonData,
                                                                method: .post) else {
                Log.error("Failed to create request for path: \(path)")
                return
            }
            do {
                let (body, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    Log.error("Failed to get response as HTTPURLResponse")
                    return
                }
                if httpResponse.statusCode != 200 {
                    logRequestError(path: path, status: httpResponse.statusCode, body: body)
                }
            } catch {
                Log.error("Request failed with error: \(error)")
            }
        }
    }
}
