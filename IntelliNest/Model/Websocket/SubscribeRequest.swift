//
//  SubscribeRequest.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-28.
//

import Foundation

enum EventType: String, Encodable {
    case stateChange = "state_changed"
}

struct SubscribeRequest: Encodable {
    let type = "subscribe_events"
    let eventType: EventType

    enum CodingKeys: String, CodingKey {
        case type
        case eventType = "event_type"
    }
}
