import Foundation

extension RestAPIService {
    /// Sends a service-call POST.
    ///
    /// - Parameter fireAndForget: when `true`, the request is sent once with no external-URL failover and any
    ///   failure is logged instead of raising the error banner. Use it for eventually-consistent commands whose
    ///   true state the reload loop reflects anyway — e.g. the Wellbeing purifier fans, whose integration holds the
    ///   HTTP response ~20 s (a `sleep` + cloud re-poll) even though the command itself lands in the first second.
    ///   Waiting on and retrying that long-held connection is what surfaced 500 / -1005 errors and double-fired the
    ///   command.
    @discardableResult
    func sendPostRequest(customPath: String? = nil,
                         json: [JSONKey: Any]?,
                         domain: Domain,
                         action: Action,
                         fireAndForget: Bool = false) async -> Bool {
        let path: String = if let customPath {
            customPath
        } else {
            "/api/services/\(domain.rawValue)/\(action.rawValue)"
        }
        let jsonData: Data? = json.flatMap { createJSONData(json: $0) }

        guard let request = createURLRequest(path: path,
                                             jsonData: jsonData,
                                             method: .post) else {
            logCreateRequestFailed(path: path, domain: domain, action: action, json: json, jsonData: jsonData)
            return false
        }

        let (statusCode, data) = await sendRequest(request)
        if statusCode == statusCodeOK {
            if let data {
                handleSuccessfulResponse(domain: domain, action: action, data: data)
            }
            return true
        }

        if fireAndForget {
            Log.error("Fire-and-forget POST failed (\(domain.rawValue), \(action.rawValue)): \(statusCode.errorDescription)")
            return false
        }

        let context = PostRetryContext(path: path,
                                       jsonData: jsonData,
                                       domain: domain,
                                       action: action,
                                       primaryURL: request.url?.absoluteString ?? "",
                                       primaryStatusCode: statusCode)
        return await retryOnExternalURL(context: context)
    }

    /// Failover path when the primary POST failed: retry on the external URL, otherwise surface the error banner.
    private func retryOnExternalURL(context: PostRetryContext) async -> Bool {
        let errorBannerTitle = "Misslyckades med att skicka request"
        let errorBannerMessageEnd = "(\(context.domain.rawValue), \(context.action.rawValue))"

        guard !context.primaryURL.contains(GlobalConstants.baseExternalUrlString) else {
            setErrorBannerText(errorBannerTitle, "\(context.primaryStatusCode.errorDescription) \(errorBannerMessageEnd)")
            return false
        }
        guard let request = createURLRequest(shouldForceExternalURL: true, path: context.path,
                                             jsonData: context.jsonData, method: .post) else {
            logCreateRequestFailed(path: context.path, domain: context.domain, action: context.action,
                                   json: nil, jsonData: context.jsonData)
            setErrorBannerText("Misslyckades med att skapa external http request",
                               "POST: \(context.path). \(context.primaryStatusCode.errorDescription)")
            return false
        }

        let (statusCodeExternal, externalData) = await sendRequest(request)
        if statusCodeExternal == statusCodeOK {
            if let externalData {
                handleSuccessfulResponse(domain: context.domain, action: context.action, data: externalData)
            }
            return true
        }
        setErrorBannerText(errorBannerTitle, "\(statusCodeExternal.errorDescription) \(errorBannerMessageEnd)")
        return false
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

private struct PostRetryContext {
    let path: String
    let jsonData: Data?
    let domain: Domain
    let action: Action
    let primaryURL: String
    let primaryStatusCode: Int
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
