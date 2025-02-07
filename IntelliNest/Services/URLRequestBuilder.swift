//
//  URLRequestBuilder.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-21.
//

import Foundation
import ShipBookSDK

struct URLRequestParameters {
    var forceURLString: String?
    let path: String
    let jsonData: Data?
    let queryParams: [String: String]?
    let method: HTTPMethod
    var timeout: CGFloat?

    init(forceURLString: String? = nil,
         path: String,
         jsonData: Data? = nil,
         queryParams: [String: String]? = nil,
         method: HTTPMethod,
         timeout: CGFloat? = nil) {
        self.forceURLString = forceURLString
        self.path = path
        self.jsonData = jsonData
        self.queryParams = queryParams
        self.method = method
        self.timeout = timeout
    }
}

@MainActor
protocol URLRequestBuilder {
    var urlString: String { get }
    func createJSONData(json: [JSONKey: Any]) -> Data?
    func createURLRequest(urlRequestParameters: URLRequestParameters) -> URLRequest?
    func getRequestHeaders() -> [String: String]
}

extension URLRequestBuilder {
    func createJSONData(json: [JSONKey: Any]) -> Data? {
        var jsonStringKeys: [String: Any] = [:]
        for key in json.keys {
            if let nestedDictionary = json[key] as? [JSONKey: Any] {
                var nestedJsonStringKeys: [String: Any] = [:]
                for nestedKey in nestedDictionary.keys {
                    nestedJsonStringKeys[nestedKey.rawValue] = nestedDictionary[nestedKey]
                }
                jsonStringKeys[key.rawValue] = nestedJsonStringKeys
            } else {
                jsonStringKeys[key.rawValue] = stringifyDateIfNeeded(value: json[key])
            }
        }
        return try? JSONSerialization.data(withJSONObject: jsonStringKeys)
    }

    func createURLRequest(urlRequestParameters: URLRequestParameters) -> URLRequest? {
        guard var components = URLComponents(string: urlRequestParameters.forceURLString ?? urlString) else {
            Log.error("Can't create url request, missing base url string")
            return nil
        }

        components.path = urlRequestParameters.path

        if let queryParams = urlRequestParameters.queryParams {
            var tempComponentParams: [URLQueryItem] = []
            for key in queryParams.keys {
                tempComponentParams.append(URLQueryItem(name: key, value: queryParams[key]))
            }

            components.queryItems = tempComponentParams
        }

        guard let url = components.url else {
            Log.error("Invalid url")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = urlRequestParameters.method.rawValue
        let headers = getRequestHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if let timeout = urlRequestParameters.timeout {
            request.timeoutInterval = timeout
        }
        if let jsonData = urlRequestParameters.jsonData {
            request.httpBody = jsonData
        }

        return request
    }

    func createURLRequest(shouldForceExternalURL: Bool = false,
                          path: String,
                          jsonData: Data? = nil,
                          queryParams: [String: String]? = nil,
                          method: HTTPMethod) -> URLRequest? {
        let forceExternalURLString = shouldForceExternalURL ? GlobalConstants.baseExternalUrlString : nil
        let urlRequestParameters = URLRequestParameters(forceURLString: forceExternalURLString,
                                                        path: path,
                                                        jsonData: jsonData,
                                                        queryParams: queryParams,
                                                        method: method)
        return createURLRequest(urlRequestParameters: urlRequestParameters)
    }

    private func stringifyDateIfNeeded(value: Any?) -> Any? {
        if let date = value as? Date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            return formatter.string(from: date)
        }

        return value
    }
}
