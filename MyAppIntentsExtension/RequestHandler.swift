//
//  RequestHandler.swift
//  MyAppIntentsExtension
//
//  Created by Tobias on 2023-04-26.
//

import Foundation

class RequestHandler {
    static let shared = RequestHandler()

    private init() {}

    func makeAPICall(urlString: String, retryUrlString: String?, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(GlobalConstants.secretHassToken)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { (data, response, error) in
                if error != nil, let retryUrlString {
                    self.makeAPICall(urlString: retryUrlString, retryUrlString: nil, completion: completion)
                } else {
                    // Call the completion handler with the data, response, and error
                    completion(data, response, error)
                }
            }.resume()
        } else {
            // Call the completion handler with an error if the URL is invalid
            completion(nil, nil, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
    }
}
