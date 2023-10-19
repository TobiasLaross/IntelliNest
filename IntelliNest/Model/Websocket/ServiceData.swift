//
//  LightServiceData.swift
//  IntelliNest
//
//  Created by Tobias on 2023-07-10.
//

import Foundation

class ServiceData: Encodable {}

class LightServiceData: ServiceData {
    let brightness: Int
    init(brightness: Int) {
        self.brightness = brightness
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(brightness, forKey: .brightness)
    }

    private enum CodingKeys: String, CodingKey {
        case brightness
    }
}

class DateTimeServiceData: ServiceData {
    let date: String?
    let time: String?

    init(date: Date) {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.date = dateFormatter.string(from: date)

        dateFormatter.dateFormat = "HH:mm:ss"
        self.time = dateFormatter.string(from: date)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let date {
            try container.encode(date, forKey: .date)
        }

        if let time {
            try container.encode(time, forKey: .time)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case time
    }
}

class EmptyServiceData: ServiceData {}
