//
//  URLCreatorDelegate.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-28.
//

import Foundation

protocol URLCreatorDelegate: AnyObject {
    func baseURLChanged(urlString: String)
    func connectionStateChanged(state: ConnectionState)
}

extension URLCreatorDelegate {
    // Function only needed for tests
    func connectionStateChanged(state: ConnectionState) {}
}
