//
//  VLCMediaplayerMock.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-10.
//

import Foundation

class VLCMediaMock {
    init(url: URL) {}
    func addOptions(_ options: [String: Int]) {}
}

protocol VLCMediaPlayerMockDelegate: AnyObject {}

enum VLCState {
    case playing
}

class VLCMediaPlayerMock {
    var drawable: Any?
    var state: VLCState?
    var delegate: VLCMediaPlayerMockDelegate?
    var media: VLCMediaMock?

    func play() {}
    func pause() {}
}
