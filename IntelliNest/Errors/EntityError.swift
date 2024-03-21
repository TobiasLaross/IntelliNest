//
//  EntityError.swift
//  IntelliNest
//
//  Created by Tobias on 2022-07-07.
//

import Foundation

enum EntityError: Error {
    case updateTooEarly
    case badRequest
    case badResponse
    case badImageData
    case httpRequestFailure
    case genericError
}
