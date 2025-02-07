import Foundation
import ShipBookSDK

// swiftlint:disable:next type_body_length file_length
@MainActor
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

    func reloadState(entityID: EntityId) async throws -> String {
        guard let request = createURLRequest(path: "/api/states/\(entityID.rawValue)", method: .get) else {
            throw EntityError.badRequest
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EntityError.badResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw EntityError.httpRequestFailure
        }

        let decoder = JSONDecoder()
        let entity = try decoder.decode(EntityMinimized.self, from: data)
        return entity.state
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

    func update(entityID: EntityId, domain: Domain, action: Action, dataKey: JSONKey, dataValue: String) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = entityID.rawValue
            json[dataKey] = dataValue
            await sendPostRequest(json: json, domain: domain, action: action)
        }
    }

    func update(entityID: EntityId, domain: Domain, action: Action, dataKey: JSONKey, dataValue: Int) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = entityID.rawValue
            json[dataKey] = dataValue
            await sendPostRequest(json: json, domain: domain, action: action)
        }
    }

    func update(entityID: EntityId, domain: Domain, action: Action, dataKey: JSONKey, dataValue: Double) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = entityID.rawValue
            json[dataKey] = dataValue
            await sendPostRequest(json: json, domain: domain, action: action)
        }
    }

    func update(numberEntityID: EntityId, number: Double) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = numberEntityID.rawValue
            json[.value] = number
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

    func setStateFor(entity: some EntityProtocol, domain: Domain, action: Action) async {
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
        formatter.dateFormat = "HH:mm:ss"
        json[.time] = formatter.string(from: dateEntity.date)

        await sendPostRequest(json: json,
                              domain: Domain.inputDateTime,
                              action: Action.setDateTime)
    }

    func sendRequest(_ request: URLRequest) async -> (Int, Data?) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                Log.error("Response was not httpResponse, for \(request.url?.absoluteString ?? "")")
                return (statusCodeBadResponse, nil)
            }

            if httpResponse.statusCode >= 300 {
                Log.error("Api status: \(httpResponse.statusCode), for \(request.url?.absoluteString ?? "Missing url")")
                return (httpResponse.statusCode, nil)
            }

            return (statusCodeOK, data)
        } catch {
            Log.error("Failed to send request: \(request.debugDescription) with error: \(error)")
            if let urlError = error as? URLError {
                return (urlError.errorCode, nil)
            } else {
                return (statusCodeFailedRequest, nil)
            }
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

    func registerAPNSToken(_ apnsToken: String) {
        let path = "/api/mobile_app/registrations"
        let user = UserManager.currentUser
        var json: [JSONKey: Any] = [:]
        json[.deviceID] = "intellinest_\(user.name)"
        json[.appID] = "intellinest"
        json[.appName] = "IntelliNest"
        json[.appVersion] = "1.0"
        json[.deviceName] = user == .sarah ? "Sarah's iPhone IntelliNest" : user == .tobias ? "Tobias iPhone IntelliNest" : ""
        json[.manufacturer] = "Apple"
        json[.model] = "iPhone"
        json[.osName] = "iOS"
        json[.osVersion] = "1.0"
        json[.supportsEncryption] = false
        let appData = [JSONKey.pushToken: apnsToken, .pushURL: "http://192.168.1.203:3000/notify"]
        json[.appData] = appData
        let capturedJSON = json
        Task {
            await sendPostRequest(customPath: path, json: capturedJSON, domain: .apnsToken, action: .register)
        }
    }
}

private extension RestAPIService {
    func logCreateRequestFailed(path _: String, domain: Domain, action: Action, json: [JSONKey: Any]? = nil, jsonData: Data? = nil) {
        Log.error("""
        Failed to create request \(json ?? [.invalid: ""]),
        \(jsonData?.debugDescription ?? "Bad JSON data"),
        \(domain), \(action)
        """)
    }

    func sendPostRequest(customPath: String? = nil, json: [JSONKey: Any]?, domain: Domain, action: Action) async {
        let path: String = if let customPath {
            customPath
        } else {
            "/api/services/\(domain.rawValue)/\(action.rawValue)"
        }
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

        var (statusCodeExternal, externalData): (Int, Data?) = (-1, nil)
        let (statusCode, data) = await sendRequest(request)
        let url = request.url?.absoluteString ?? ""
        if statusCode != statusCodeOK {
            if !url.contains(GlobalConstants.baseExternalUrlString) {
                guard let request = createURLRequest(shouldForceExternalURL: true, path: path, jsonData: jsonData, method: .post) else {
                    logCreateRequestFailed(path: path, domain: domain, action: action, json: json, jsonData: jsonData)
                    setErrorBannerText("Misslyckades med att skapa external http request", "POST: \(path). \(statusCode.errorDescription)")
                    return
                }

                (statusCodeExternal, externalData) = await sendRequest(request)
                if statusCodeExternal != statusCodeOK {
                    setErrorBannerText(errorBannerTitle, "\(statusCodeExternal.errorDescription) \(errorBannerMessageEnd)")
                } else if let externalData {
                    handleSuccessfulResponse(domain: domain, action: action, data: externalData)
                }
            }
            if statusCode != statusCodeOK, statusCodeExternal != statusCodeOK {
                let errorCode = statusCode != statusCodeOK ? statusCode : statusCodeExternal
                setErrorBannerText(errorBannerTitle, "\(errorCode.errorDescription) \(errorBannerMessageEnd)")
            }
        } else if let data {
            handleSuccessfulResponse(domain: domain, action: action, data: data)
        }
    }

    func handleSuccessfulResponse(domain: Domain, action: Action, data: Data) {
        if domain == .apnsToken && action == .register {
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let webhookId = jsonResponse["webhook_id"] as? String {
                        print("Webhook response: \(webhookId)")
                        UserDefaults.standard.setValue(webhookId, forKey: StorageKeys.webhookID.rawValue)
                    } else {
                        Log.error("webhook_id not found in response")
                    }
                }
            } catch {
                Log.error("Error parsing response JSON: \(error)")
            }
        }
    }
}

private extension Int {
    var errorDescription: String {
        switch self {
        case -1001:
            "Förfrågan tog för lång tid"
        case -1003:
            "Kan inte hitta servern"
        case -1004:
            "Kan inte ansluta till servern"
        case -1009:
            "Ingen nätverksåtkomst"
        case 400:
            "Felaktikt request: 400"
        default:
            "Ohanterad felkod: \(self)"
        }
    }
}
