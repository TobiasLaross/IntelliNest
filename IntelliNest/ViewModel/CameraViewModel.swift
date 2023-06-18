//
//  CameraViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-28.
//

import Foundation
// import MobileVLCKit
import ShipBookSDK
import Starscream
import SwiftUI

class CameraViewModel: NSObject, ObservableObject {
    @Published var snapshot: Image?
    @Published var isLoading: Bool = false
    @Published var mediaPlayer: VLCMediaPlayerMock? // VLCMediaPlayer?
    @Published var isPlaying = false
    private var bufferTime = 1000 // Milliseconds
    var snapshotScale: CGFloat
    let initialSnapshotScale: CGFloat
    var socket: WebSocket?
    var shouldPlayMedia = false { didSet {
        Task { @MainActor in
            if !oldValue && shouldPlayMedia {
                mediaPlayer?.play()
            } else if !shouldPlayMedia {
                mediaPlayer?.pause()
            }
        }
    }}

    let urlCreator: URLCreator
    let entityID: EntityId
    let localURL: String
    let isPortait: Bool
    private var requestIDs: [Int] = []

    var remoteURL: String?
    var isLocallyConnected: Bool {
        urlCreator.connectionState == .local
    }

    init(urlCreator: URLCreator, cameraEntityID: EntityId, localURL: String, isPortait: Bool) {
        self.urlCreator = urlCreator
        self.entityID = cameraEntityID
        self.localURL = localURL
        self.isPortait = isPortait
        if cameraEntityID == .cameraFront {
            initialSnapshotScale = 1.0
        } else {
            initialSnapshotScale = 0.55
        }
        snapshotScale = initialSnapshotScale
        super.init()
        if isLocallyConnected {
//            setupStream()  Don't set up camera streams, VLC is too slow when loading
        }
    }

    func setupStream() {
        Task { @MainActor in
            guard let urlString = isLocallyConnected ? localURL : remoteURL, let url = URL(string: urlString) else {
                Log.error("Failed to setup stream, not valid url: local? \(isLocallyConnected) ? \(localURL) : \(remoteURL ?? "no url")")
                return
            }

            let media = VLCMediaMock(url: url)
            media.addOptions([
                "network-caching": bufferTime
            ])
            mediaPlayer = VLCMediaPlayerMock()
            mediaPlayer?.delegate = self
            mediaPlayer?.media = media
            if shouldPlayMedia {
                mediaPlayer?.play()
            }
        }
    }

    func setRemoteURL(stringURL: String) {
        remoteURL = "\(GlobalConstants.baseExternalUrlString.removingTrailingSlash)\(stringURL)"
        if !isLocallyConnected {
//            setupStream()  Don't set up camera streams, VLC is too slow when loading
        }
    }

    func appendRequestID(_ requestID: Int) {
        requestIDs.append(requestID)
    }

    func hasRequestID(_ requestID: Int) -> Bool {
        requestIDs.contains(requestID)
    }
}

extension CameraViewModel: VLCMediaPlayerMockDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        if let player = aNotification.object as? VLCMediaPlayerMock {
            if player.state == .playing {
                Task { @MainActor in
                    isPlaying = true
                }
            }
        }
    }
}
