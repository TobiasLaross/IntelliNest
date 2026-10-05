//
//  Navigator+MusicLiveActivity.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import Foundation

extension Navigator {
    /// Brings the now-playing Live Activity in line with the speakers, for a user who is home. Called from the
    /// reload loop, so it reloads the speakers itself whenever the music screen isn't already doing it.
    func syncMusicLiveActivity() async {
        guard let isHome = await isCurrentUserHome() else {
            return
        }
        guard isHome else {
            await MusicLiveActivityController.shared.end()
            return
        }
        if currentDestination != .music {
            await musicViewModel.reloadSpeakers()
        }
        await MusicLiveActivityController.shared.sync(musicViewModel.liveActivitySnapshot())
    }

    /// Reads the user's away boolean in Home Assistant, which the geofence keeps current. Nil when it can't be read,
    /// so a network blip leaves the activity alone instead of ending it.
    private func isCurrentUserHome() async -> Bool? {
        guard let awayEntityID = UserManager.currentUserAwayEntityID else {
            return false
        }
        do {
            return try await !restAPIService.get(entityId: awayEntityID, entityType: Entity.self).isActive
        } catch {
            Log.debug("Kunde inte läsa närvaro för Live Activity: \(error)")
            return nil
        }
    }
}

extension Navigator {
    /// Answers a tap on the Live Activity: the music screen with the full-screen player over it.
    func openNowPlaying() async {
        if currentDestination != .music {
            navigationPath = [.music]
        }
        isNowPlayingRequested = true
        // After a cold launch the speakers aren't loaded yet, and the player has nothing to show without one.
        if musicViewModel.displayedActiveSpeaker == nil {
            await reload(for: .music)
        } else {
            presentRequestedNowPlaying()
        }
    }

    /// Opens the player for a pending Live Activity tap once there is a speaker to show. A reload can be skipped
    /// while another is in flight, so the request waits for the first one that finds a speaker; leaving the music
    /// screen drops it, so the player can't pop up later out of nowhere.
    func presentRequestedNowPlaying() {
        guard isNowPlayingRequested, musicViewModel.displayedActiveSpeaker != nil else {
            return
        }
        isNowPlayingRequested = false
        musicViewModel.isShowingNowPlaying = true
    }
}
