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
