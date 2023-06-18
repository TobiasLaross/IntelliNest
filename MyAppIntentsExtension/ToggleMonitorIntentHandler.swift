//
//  ToggleMonitorIntentHandler.swift
//  MyAppIntentsExtension
//
//  Created by Tobias on 2023-04-26.
//

import Intents

class ToggleMonitorIntentHandler: NSObject, ToggleMonitorIntentHandling {
    func handle(intent: ToggleMonitorIntent, completion: @escaping (ToggleMonitorIntentResponse) -> Void) {
        let path = "api/services/script/toggle_monitor_in_office"
        let internalUrlString = GlobalConstants.baseInternalUrlString + path
        let externalUrlString = GlobalConstants.baseExternalUrlString + path

        RequestHandler.shared.makeAPICall(urlString: internalUrlString, retryUrlString: externalUrlString) { (_, response, error) in
            if error != nil {
                // Handle the error if both requests fail
                let response = ToggleMonitorIntentResponse(code: .failure, userActivity: nil)
                completion(response)
            } else {
                // Handle the success if one of the requests succeeds
                let response = ToggleMonitorIntentResponse(code: .success, userActivity: nil)
                completion(response)
            }
        }
    }
}
