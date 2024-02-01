//
//  RestAPIService.swift
//  IntelliNest
//
//  Created by Tobias on 2022-07-07.
//

import Foundation
import ShipBookSDK
import SwiftUI
import UIKit

// swiftlint: disable:next type_body_length
class RestAPIService: URLRequestBuilder {
    var urlString: String {
        urlCreator.urlString
    }

    private let statusCodeOK = 0
    private let statusCodeBadRequest = 1
    private let statusCodeBadResponse = 2
    private let statusCodeFailedRequest = 3

    private let urlCreator: URLCreator
    private let session: URLSession
    private let setErrorBannerText: StringStringClosure

    init(urlCreator: URLCreator, session: URLSession = .shared, setErrorBannerText: @escaping StringStringClosure) {
        self.urlCreator = urlCreator
        self.session = session
        self.setErrorBannerText = setErrorBannerText
    }

    func reload<T: EntityProtocol>(entityId: EntityId, entityType: T.Type) async throws -> T {
        var updatedEntity: T

        do {
            try await updatedEntity = get(entityId: entityId, entityType: entityType)
            return updatedEntity
        } catch EntityError.badRequest {
            Log.error("Failed to create request")
        } catch EntityError.updateTooEarly {
            Log.info("Tried to update \(entityId) too early")
        } catch EntityError.httpRequestFailure {
            Log.error("Failed to reload \(entityId), status code not ok")
        } catch EntityError.badResponse {
            Log.error("Failed to reload \(entityId), bad response")
        } catch {
            Log.error("Unknown error when updating \(entityId) with error: \(error)")
        }

        throw EntityError.genericError
    }

    func reload<T: EntityProtocol>(hassEntity: T, entityType: T.Type) async -> T {
        if GlobalConstants.isGithubActionsRunning() {
            return hassEntity
        }

        do {
            return try await get(entityId: hassEntity.entityId, entityType: entityType)
        } catch EntityError.badRequest {
            Log.error("Failed to create request")
        } catch EntityError.updateTooEarly {
            Log.info("Tried to update \(hassEntity.entityId) too early")
        } catch EntityError.httpRequestFailure {
            Log.error("Failed to reload \(hassEntity.entityId), status code not ok")
        } catch EntityError.badResponse {
            Log.error("Failed to reload \(hassEntity.entityId), bad response")
        } catch {
            Log.error("Unknown error when updating \(hassEntity.entityId) with error: \(error)")
        }

        return hassEntity
    }

    @MainActor
    func get<T: EntityProtocol>(entityId: EntityId, entityType: T.Type) async throws -> T {
        guard let request = createURLRequest(path: "/api/states/\(entityId.rawValue)",
                                             method: .get) else {
            throw EntityError.badRequest
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EntityError.badResponse
        }

        /* Testing purposes
         if entityId == .roborockLastCleanArea {
         if let string = String(data: data, encoding: .utf8) {
         print(string)
         }
         } */

        guard httpResponse.statusCode == 200 else {
            throw EntityError.httpRequestFailure
        }

        let decoder = JSONDecoder()
        return try decoder.decode(entityType.self, from: data)
    }

    // MARK: Post requests

    func update(entityID: EntityId, domain: Domain, action: Action) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = entityID.rawValue
            await sendPostRequest(json: json, domain: domain, action: action)
        }
    }

    func update(lightIDs: [EntityId], action: Action, brightness: Int) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for lightID in lightIDs {
                    group.addTask {
                        var json = [JSONKey: Any]()
                        json[.entityID] = lightID.rawValue
                        if action == .turnOn && brightness > 0 {
                            json[.brightness] = brightness
                        }

                        await self.sendPostRequest(json: json, domain: .light, action: action)
                    }
                }
            }
        }
    }

    func update(dateEntityID: EntityId, date: Date) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = dateEntityID.rawValue
            json[.dateTime] = date
            await sendPostRequest(json: json, domain: .inputDateTime, action: .setDateTime)
        }
    }

    func update(heaterID: EntityId, domain: Domain = .climate, action: Action, dataKey: JSONKey, dataValue: String) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = heaterID.rawValue
            json[dataKey] = dataValue
            await sendPostRequest(json: json, domain: domain, action: action)
        }
    }

    func update(numberEntityID: EntityId, number: Double) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = numberEntityID.rawValue
            json[.inputNumberValue] = number
            await sendPostRequest(json: json, domain: .inputNumber, action: .setValue)
        }
    }

    func callService(serviceID: ServiceID, domain: Domain, json: [JSONKey: Any]? = nil) {
        Task {
            if let action = serviceID.toAction {
                await sendPostRequest(json: json, domain: domain, action: action)
            } else {
                setErrorBannerText("Misslyckades med att anropa service",
                                   "\(serviceID.rawValue) gick inte att konvertera till action")
            }
        }
    }

    func setStateFor(lock: LockEntity, action: Action) async {
        guard let action = Action(rawValue: action.rawValue) else {
            Log.error("Bad action: \(action.rawValue)")
            return
        }

        await setStateFor(entity: lock, domain: .lock, action: action)
    }

    func setState(for entityId: EntityId, in domain: Domain, using action: Action) async {
        var json = [JSONKey: Any]()
        json[JSONKey.entityID] = entityId.rawValue
        await sendPostRequest(json: json, domain: domain, action: action)
    }

    func setStateFor<T: EntityProtocol>(entity: T, domain: Domain, action: Action) async {
        var json = [JSONKey: Any]()
        json[JSONKey.entityID] = entity.entityId.rawValue
        await sendPostRequest(json: json, domain: domain, action: action)
    }

    func callScript(scriptID: ScriptID, variables: [ScriptVariableKeys: String]? = nil) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = scriptID.rawValue
            if let variables {
                var variableDict = [String: String]()
                for (key, value) in variables {
                    variableDict[key.rawValue] = value
                }

                json[.variables] = variableDict
            }
            await sendPostRequest(json: json, domain: .script, action: .turnOn)
        }
    }

    func setDateTimeEntity(dateEntity: Entity) async {
        var json = [JSONKey: Any]()
        json[.entityID] = dateEntity.entityId.rawValue
        let formatter = DateFormatter()
        if dateEntity.entityId == .eniroClimateSchedule3 {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            json[.dateTime] = formatter.string(from: dateEntity.date)
        } else {
            formatter.dateFormat = "HH:mm:ss"
            json[.time] = formatter.string(from: dateEntity.date)
        }

        await sendPostRequest(json: json,
                              domain: Domain.inputDateTime,
                              action: Action.setDateTime)
    }

    private func sendPostRequest(json: [JSONKey: Any]?, domain: Domain, action: Action) async {
        let path = "/api/services/\(domain.rawValue)/\(action.rawValue)"
        let errorBannerTitle = "Misslyckades med att skicka request"
        let errorBannerMessageEnd = "(\(domain.rawValue), \(action.rawValue))"
        var jsonData: Data?
        if let json {
            jsonData = createJSONData(json: json)
        }

        guard let request = createURLRequest(path: path,
                                             jsonData: jsonData,
                                             method: .post) else {
            logCreateRequestFailed(path: path, domain: domain, action: action, json: json, jsonData: jsonData)
            return
        }

        let statusCode = await sendRequest(request: request)
        var statusCodeExternal = statusCodeOK
        let url = request.url?.absoluteString ?? ""
        if statusCode != statusCodeOK {
            if !url.contains(GlobalConstants.baseExternalUrlString) {
                guard let request = createURLRequest(shouldForceExternalURL: true, path: path, jsonData: jsonData, method: .post) else {
                    logCreateRequestFailed(path: path, domain: domain, action: action, json: json, jsonData: jsonData)
                    setErrorBannerText("Misslyckades med att skapa external http request", "POST: \(path). \(statusCode.errorDescription)")
                    return
                }

                statusCodeExternal = await sendRequest(request: request)
                if statusCodeExternal != statusCodeOK {
                    setErrorBannerText(errorBannerTitle, "\(statusCodeExternal.errorDescription) \(errorBannerMessageEnd)")
                }
            }
            if statusCode != statusCodeOK || statusCodeExternal != statusCodeOK {
                let errorCode = statusCode != statusCodeOK ? statusCode : statusCodeExternal
                setErrorBannerText(errorBannerTitle, "\(errorCode.errorDescription) \(errorBannerMessageEnd)")
            }
        }
    }

    func sendRequest(request: URLRequest) async -> Int {
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                Log.error("Response was not httpResponse, for \(request.url?.absoluteString ?? "")")
                return statusCodeBadResponse
            }

            if httpResponse.statusCode >= 300 {
                Log.error("Api status: \(httpResponse.statusCode), for \(request.url?.absoluteString ?? "Missing url")")
                return httpResponse.statusCode
            }
        } catch {
            Log.error("Failed to send request: \(request.debugDescription) with error: \(error)")
            if let urlError = error as? URLError {
                return urlError.errorCode
            } else {
                return statusCodeFailedRequest
            }
        }

        return statusCodeOK
    }

    func getRequestHeaders() -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": "Bearer \(GlobalConstants.secretHassToken)"
        ]
    }

    func getCameraSnapshot(for cameraID: EntityId) async throws -> Image {
        guard let request = createURLRequest(path: "/api/camera_proxy/\(cameraID.rawValue)",
                                             method: .get) else {
            throw EntityError.badRequest
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EntityError.badResponse
        }

        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        } else {
            throw EntityError.badImageData
        }
    }

    func downloadImage(urlPath: String, queryParams: [String: String]? = nil) async throws -> UIImage? {
        guard urlPath.isNotEmpty else {
            throw EntityError.badRequest
        }

        let urlPathSeparated = urlPath.components(separatedBy: "?token=")
        var request: URLRequest?
        if urlPathSeparated.count == 2 {
            request = createURLRequest(path: urlPathSeparated[0],
                                       queryParams: ["token": urlPathSeparated[1]],
                                       method: .get)
        } else {
            request = createURLRequest(path: urlPath,
                                       queryParams: queryParams,
                                       method: .get)
        }

        guard let request else {
            throw EntityError.badRequest
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EntityError.badResponse
        }

        guard httpResponse.statusCode == 200 else {
            Log.error("Api status for download image: \(httpResponse.statusCode), for \(request.url?.absoluteString ?? "")")
            throw EntityError.httpRequestFailure
        }

        return UIImage(data: data)
    }
}

private extension RestAPIService {
    func setBoolEntity(_ entityID: EntityId, path: String) {
        Task {
            let jsonData = createJSONData(json: [.entityID: entityID.rawValue])
            let urlRequestParameters = URLRequestParameters(forceURLString: GlobalConstants.baseExternalUrlString,
                                                            path: path,
                                                            jsonData: jsonData,
                                                            method: .post,
                                                            timeout: 1.0)
            let request = createURLRequest(urlRequestParameters: urlRequestParameters)
            if let request {
                _ = await sendRequest(request: request)
            }
        }
    }

    func logCreateRequestFailed(path: String, domain: Domain, action: Action, json: [JSONKey: Any]? = nil, jsonData: Data? = nil) {
        Log.error("""
        Failed to create request \(json ?? [.invalid: ""]),
        \(jsonData?.debugDescription ?? "Bad JSON data"),
        \(domain), \(action)
        """)
    }
}

private extension Int {
    var errorDescription: String {
        switch self {
        case -1001:
            return "Förfrågan tog för lång tid"
        case -1003:
            return "Kan inte hitta servern"
        case -1004:
            return "Kan inte ansluta till servern"
        case -1009:
            return "Ingen nätverksåtkomst"
        case 400:
            return "Felaktikt request: 400"
        default:
            return "Ohanterad felkod: \(self)"
        }
    }
}
