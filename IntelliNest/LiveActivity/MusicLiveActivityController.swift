//
//  MusicLiveActivityController.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import ActivityKit
import CryptoKit
import Foundation
import UIKit

/// What the music view model hands the Live Activity: the state to show, and the album art still to be cached.
struct MusicNowPlayingSnapshot: Equatable {
    var state: MusicActivityAttributes.ContentState
    var artworkPath: String?
}

/// Owns the now-playing Live Activity. The `Navigator` reload loop feeds it while the app is open; between those
/// updates the lock screen advances the progress bar on its own. Button presses arrive through
/// `MusicActivityCommandRouter`, possibly in a background launch with no `Navigator`, so this keeps its own
/// connection to Home Assistant.
@MainActor
final class MusicLiveActivityController {
    static let shared = MusicLiveActivityController()

    private let urlCreator = URLCreator()
    private lazy var restAPIService = RestAPIService(urlCreator: urlCreator,
                                                     setErrorBannerText: { _, _ in },
                                                     repeatReloadAction: { _ in })
    private var cachedArtwork: (path: String, fileName: String)?
    private let relay = MusicActivityRelay()
    /// The running activity's ActivityKit push token, which the relay needs to update it while the app is closed.
    private var activityPushToken: String?

    /// `Activity` isn't `Sendable`, so it never leaves these nonisolated helpers: only its state crosses over.
    private nonisolated static var currentState: MusicActivityAttributes.ContentState? {
        Activity<MusicActivityAttributes>.activities.first?.content.state
    }

    private nonisolated static func update(to state: MusicActivityAttributes.ContentState) async {
        await Activity<MusicActivityAttributes>.activities.first?.update(ActivityContent(state: state, staleDate: nil))
    }

    private nonisolated static func start(with state: MusicActivityAttributes.ContentState) throws {
        let activity = try Activity.request(attributes: MusicActivityAttributes(),
                                            content: ActivityContent(state: state, staleDate: nil),
                                            pushType: .token)
        Task {
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                await MusicLiveActivityController.shared.didReceivePushToken(token)
            }
        }
    }

    private nonisolated static func endAll() async {
        for activity in Activity<MusicActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func registerCommandHandler() {
        MusicActivityCommandRouter.handler = { [weak self] command in
            await self?.perform(command)
        }
    }

    /// Starts, updates or ends the activity to match `snapshot`; nil ends it. Starting only works while the app is
    /// in the foreground, which is the only time the reload loop calls this.
    func sync(_ snapshot: MusicNowPlayingSnapshot?) async {
        guard let snapshot else {
            await end()
            return
        }
        var state = snapshot.state
        state.artworkFileName = await artworkFileName(for: snapshot.artworkPath)
        if let currentState = Self.currentState {
            guard currentState != state else {
                return
            }
            await apply(state)
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                try Self.start(with: state)
            } catch {
                Log.warning("Kunde inte starta musikens Live Activity: \(error)")
            }
        }
    }

    func end() async {
        guard Self.currentState != nil else {
            return
        }
        await Self.endAll()
        if let activityPushToken {
            self.activityPushToken = nil
            await relay.unregister(pushToken: activityPushToken)
        }
    }

    /// Shows `state` and hands it to the relay, which builds its pushes on top of the last state it was given.
    private func apply(_ state: MusicActivityAttributes.ContentState) async {
        await Self.update(to: state)
        await registerWithRelay(state)
    }

    private func didReceivePushToken(_ token: String) async {
        activityPushToken = token
        if let state = Self.currentState {
            await registerWithRelay(state)
        }
    }

    private func registerWithRelay(_ state: MusicActivityAttributes.ContentState) async {
        guard let activityPushToken else {
            return
        }
        let deviceToken = UserDefaults.standard.string(forKey: StorageKeys.apnsDeviceToken.rawValue)
        await relay.register(pushToken: activityPushToken, deviceToken: deviceToken, state: state)
    }

    private func perform(_ command: MusicActivityCommand) async {
        guard let state = Self.currentState else {
            return
        }
        let optimistic = MusicActivityCommandSender.optimisticState(after: command, from: state, asOf: Date())
        if optimistic != state {
            await apply(optimistic)
        }
        if urlCreator.connectionState == .unset {
            await urlCreator.updateConnectionState()
        }
        await MusicActivityCommandSender(restAPIService: restAPIService).send(command, for: state)
        if command == .nextTrack || command == .previousTrack {
            await refreshTrack(afterSkip: true)
        }
    }

    /// Re-reads the playing track, with its album art, into the activity: after a skip, and when the relay's
    /// background push says the track changed. The app may be in the background with no reload loop running.
    func refreshTrack(afterSkip: Bool = false) async {
        if afterSkip {
            // Music Assistant reports the new track a beat after the skip is accepted.
            try? await Task.sleep(for: .seconds(1.5))
        }
        if urlCreator.connectionState == .unset {
            await urlCreator.updateConnectionState()
        }
        guard let state = Self.currentState,
              let targetID = EntityId(rawValue: state.transportTargetID),
              let player = try? await restAPIService.reload(entityId: targetID, entityType: MediaPlayerEntity.self),
              player.hasLiveAudio,
              let title = player.mediaTitle, title.isNotEmpty else {
            return
        }
        var refreshed = state
        refreshed.title = title
        refreshed.artist = player.mediaArtist
        refreshed.isPlaying = player.isPlaying
        refreshed.position = player.mediaPosition
        refreshed.positionDate = player.mediaPositionUpdatedAt
        refreshed.duration = player.mediaDuration
        refreshed.artworkFileName = await artworkFileName(for: player.entityPicture)
        await apply(refreshed)
    }

    /// Downloads and shrinks the album art into the shared container, returning the file name the widget reads.
    /// Only the latest artwork is kept on disk.
    private func artworkFileName(for path: String?) async -> String? {
        guard let path, let url = AlbumArtView.resolvedURL(for: path) else {
            return nil
        }
        if let cachedArtwork, cachedArtwork.path == path {
            return cachedArtwork.fileName
        }
        guard let directoryURL = MusicActivityArtwork.directoryURL,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let jpeg = Self.thumbnailJPEG(from: data) else {
            return nil
        }
        let digest = SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        let fileName = "\(digest.prefix(16)).jpg"
        do {
            try? FileManager.default.removeItem(at: directoryURL)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try jpeg.write(to: directoryURL.appendingPathComponent(fileName))
        } catch {
            Log.warning("Kunde inte spara skivomslaget för Live Activity: \(error)")
            return nil
        }
        cachedArtwork = (path, fileName)
        return fileName
    }

    /// Live Activity images must stay small, so the art is scaled down to what the lock screen actually draws.
    private static func thumbnailJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }
        let side: CGFloat = 180
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let thumbnail = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return thumbnail.jpegData(compressionQuality: 0.8)
    }
}
