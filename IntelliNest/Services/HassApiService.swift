//
//  LightApiService.swift
//  IntelliNest
//
//  Created by Tobias on 2022-07-07.
//

import Foundation
import ShipBookSDK
import SwiftUI
import UIKit

class HassApiService: URLRequestBuilder {
    var urlString: String {
        urlCreator.urlString
    }

    var urlCreator: URLCreator
    private let session: URLSession

    init(urlCreator: URLCreator, session: URLSession = .shared) {
        self.urlCreator = urlCreator
        self.session = session
    }

    func reloadUntilUpdated<T: EntityProtocol>(hassEntity: T, entityType: T.Type) async -> T {
        var counter = 0
        var updatedEntity = hassEntity
        var sleepSeconds = 0.1

        repeat {
            do {
                try await Task.sleep(seconds: sleepSeconds)
            } catch {
                Log.error("Failed to sleep: \(error)")
            }
            updatedEntity = await reload(hassEntity: hassEntity, entityType: entityType)
            counter += 1
            sleepSeconds += 0.05
        } while updatedEntity == hassEntity && counter < 20

        return updatedEntity
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

    func setState(light: LightEntity, action: Action) async {
        var json = [JSONKey: Any]()
        json[JSONKey.entityID] = light.entityId.rawValue
        if action == .turnOn && light.brightness > 0 {
            json[JSONKey.brightness] = light.brightness
        }

        await sendPostRequest(json: json, domain: Domain.light, action: action)
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

    func callScript(entityId: EntityId, variables: [ScriptVariableKeys: String]? = nil) async {
        var json = [JSONKey: Any]()
        json[.entityID] = entityId.rawValue
        if let variables {
            var variableDict = [String: String]()
            for (key, value) in variables {
                variableDict[key.rawValue] = value
            }

            json[.variables] = variableDict
        }
        await sendPostRequest(json: json, domain: .script, action: .turnOn)
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

    func sendPostRequest(json: [JSONKey: Any]?, domain: Domain, action: Action) async {
        var jsonData: Data?
        if let json {
            jsonData = createJSONData(json: json)
        }

        guard let request = createURLRequest(path: "/api/services/\(domain.rawValue)/\(action.rawValue)",
                                             jsonData: jsonData,
                                             method: .post) else {
            Log.error("""
            Failed to create request \(json ?? [.invalid: ""]),
            \(jsonData?.debugDescription ?? "Bad JSON data"),
            \(domain), \(action)
            """)
            return
        }

        await sendRequest(request: request)
    }

    func sendRequest(request: URLRequest) async {
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                Log.error("Response was not httpResponse, for \(request.url?.absoluteString ?? "")")
                return
            }

            if httpResponse.statusCode > 299 {
                Log.error("Api status: \(httpResponse.statusCode), for \(request.url?.absoluteString ?? "Missing url")")
                return
            }
        } catch {
            Log.error("Request failed with error: \(error)")
        }
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

    func turnOnBoolEntity(_ entityID: EntityId, useExternalURL: Bool) {
        setBoolEntity(entityID, useExternalURL: useExternalURL, path: "/api/services/input_boolean/turn_on")
    }

    func turnOffBoolEntity(_ entityID: EntityId, useExternalURL: Bool) {
        setBoolEntity(entityID, useExternalURL: useExternalURL, path: "/api/services/input_boolean/turn_off")
    }

    private func setBoolEntity(_ entityID: EntityId, useExternalURL: Bool, path: String) {
        Task {
            let jsonData = createJSONData(json: [.entityID: entityID.rawValue])
            let urlRequestParameters = URLRequestParameters(forceURLString: GlobalConstants.baseExternalUrlString,
                                                            path: path,
                                                            jsonData: jsonData,
                                                            method: .post,
                                                            timeout: 1.0)
            let request = createURLRequest(urlRequestParameters: urlRequestParameters)
            if let request {
                await sendRequest(request: request)
            }
        }
    }
}
