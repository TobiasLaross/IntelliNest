//
//  UnlockStoreHouseIntentHandler.swift
//  MyAppIntentsExtension
//
//  Created by Tobias on 2023-04-21.
//

import Intents

class UnlockStoreHouseIntentHandler: NSObject, UnlockStoreHouseIntentHandling {
    func handle(intent: UnlockStoreHouseIntent, completion: @escaping (UnlockStoreHouseIntentResponse) -> Void) {
        let path = "api/services/script/toggle_storage_unit_lock"
        let internalUrlString = GlobalConstants.baseInternalUrlString + path
        let externalUrlString = GlobalConstants.baseExternalUrlString + path

        RequestHandler.shared.makeAPICall(urlString: internalUrlString, retryUrlString: externalUrlString) { (_, response, error) in
            if error != nil {
                // Handle the error if both requests fail
                let response = UnlockStoreHouseIntentResponse(code: .failure, userActivity: nil)
                completion(response)
            } else {
                // Handle the success if one of the requests succeeds
                let response = UnlockStoreHouseIntentResponse(code: .success, userActivity: nil)
                completion(response)
            }
        }
    }
}
