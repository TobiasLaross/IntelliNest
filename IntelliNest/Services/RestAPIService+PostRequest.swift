import Foundation
import ShipBookSDK

extension RestAPIService {
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

    private func logCreateRequestFailed(
        path _: String,
        domain: Domain,
        action: Action,
        json _: [JSONKey: Any]? = nil,
        jsonData _: Data? = nil
    ) {
        Log.error("Failed to create request (\(domain), \(action))")
    }

    private func handleSuccessfulResponse(domain: Domain, action: Action, data: Data) {
        if domain == .apnsToken && action == .register {
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let webhookId = jsonResponse["webhook_id"] as? String {
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
