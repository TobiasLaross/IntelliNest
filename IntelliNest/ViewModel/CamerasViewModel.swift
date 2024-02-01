//
//  CamerasViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-02.
//

import Foundation
import ShipBookSDK
import SwiftUI

class CamerasViewModel: ObservableObject {
    private let urlCreator: URLCreator
    var cameraViewModels: [CameraViewModel] = []
    var isActiveScreen = false { didSet {
        snapshotTask?.cancel()
    }}
    var snapshotTask: Task<Void, Error>?
    let websocketService: WebsocketServiceProtocol
    let apiService: RestAPIService

    init(urlCreator: URLCreator, websocketService: WebsocketServiceProtocol, apiService: RestAPIService) {
        self.urlCreator = urlCreator
        self.websocketService = websocketService
        self.apiService = apiService

        let cameraEntityIDs: [EntityId] = [.cameraFront, .cameraBack, .cameraCarport, .cameraVince]
        for cameraEntityID in cameraEntityIDs {
            let cameraViewModel = CameraViewModel(urlCreator: urlCreator,
                                                  cameraEntityID: cameraEntityID,
                                                  localURL: secretRTSPURL(for: cameraEntityID),
                                                  isPortait: cameraEntityID == .cameraFront)
            cameraViewModels.append(cameraViewModel)
        }

//        requestRemoteCameraURLs() Don't set up cameras VLC is too slow to load
    }

    func setRTSPURL(urlString: String, for resultID: Int) {
        if let cameraViewModel = findCameraViewModel(for: resultID) {
            cameraViewModel.setRemoteURL(stringURL: urlString)
        } else {
            Log.error("Not implemented setRTSPURL for \(resultID)")
        }
    }

    func findCameraViewModel(for entiyID: EntityId) -> CameraViewModel? {
        return cameraViewModels.first(where: { $0.entityID == entiyID })
    }

    private func findCameraViewModel(for resultID: Int) -> CameraViewModel? {
        return cameraViewModels.first(where: { $0.hasRequestID(resultID) })
    }

    private func requestRemoteCameraURLs() {
        for cameraViewModel in cameraViewModels {
            let id = websocketService.sendCameraStreamRequest(for: cameraViewModel.entityID)
            cameraViewModel.appendRequestID(id)
        }
    }

    func setIsActiveScreen(_ isActiveScreen: Bool) {
        self.isActiveScreen = isActiveScreen
        if isActiveScreen {
            getCameraSnapshots()
        }
    }

    func getCameraSnapshots() {
        snapshotTask?.cancel()
        snapshotTask = Task { @MainActor in
            while isActiveScreen {
                await withThrowingTaskGroup(of: Void.self) { group in
                    for cameraViewModel in cameraViewModels.filter({ !($0.isPlaying) }) {
                        group.addTask { @MainActor in
                            cameraViewModel.snapshot = try await self.apiService.getCameraSnapshot(for: cameraViewModel.entityID)
                        }
                    }
                }
                try? await Task.sleep(seconds: 0.1)
            }
        }
    }

    private func secretRTSPURL(for entityID: EntityId) -> String {
        switch entityID {
        case .cameraBack:
            return GlobalConstants.secretRTSPURLBackCamera
        case .cameraFront:
            return GlobalConstants.secretRTSPURLFrontCamera
        case .cameraCarport:
            return GlobalConstants.secretRTSPURLCarportkCamera
        case .cameraVince:
            return GlobalConstants.secretRTSPURLVinceCamera
        default:
            Log.error("Secret RTSP URL not implemented for \(entityID)")
            return ""
        }
    }
}
