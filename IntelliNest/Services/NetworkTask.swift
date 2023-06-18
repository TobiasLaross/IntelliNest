//
//  NetworkTask.swift
//  IntelliNest
//
//  Created by Tobias on 2022-05-25.
//

import Foundation

protocol NetworkTask {
    func resume()
}

extension URLSessionDataTask: NetworkTask {}
