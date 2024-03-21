//
//  HassAPIViewModelProtocol.swift
//  IntelliNest
//
//  Created by Tobias on 2023-04-30.
//

import Foundation

protocol HassAPIViewModelProtocol: ObservableObject {
    @MainActor
    func reload() async
}
