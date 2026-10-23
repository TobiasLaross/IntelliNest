//
//  MusicViewModel+QueueJump.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-23.
//

import Foundation

extension MusicViewModel {
    /// Whether tapping the row can jump playback to it: only a server-backed item
    /// can, since a session-fallback row has no queue item id Music Assistant knows.
    func canPlayQueueItem(_ item: MusicQueueItem) -> Bool {
        queue.queueID != nil && !sessionEnqueuedItems.contains { $0.id == item.id }
    }

    /// Jumps playback to an upcoming track, the way tapping a row in Spotify's
    /// queue does: the tapped track becomes "Spelas nu" and everything queued
    /// before it is skipped. Optimistic; reverts and banners if the socket fails.
    func playQueueItem(_ item: MusicQueueItem) async {
        guard let queueID = queue.queueID,
              canPlayQueueItem(item),
              let index = queue.upcomingItems.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        let previousQueue = queue
        let previousManualIDs = manualQueueItemIDs
        let previousSession = sessionEnqueuedItems
        let skipped = queue.upcomingItems[..<index]

        manualQueueItemIDs.subtract(skipped.map(\.id))
        manualQueueItemIDs.remove(item.id)
        queue = MusicQueue(queueID: queueID,
                           currentItem: item,
                           upcomingItems: Array(queue.upcomingItems[(index + 1)...]),
                           manualItemIDs: manualQueueItemIDs)
        // Skipped and now-playing tracks are no longer upcoming, so their session
        // fallback rows must not resurface on an offline reload.
        for passed in skipped + [item] {
            removeSessionRow(matching: passed)
        }

        let success = await queueSocket.playItem(queueID: queueID, itemID: item.queueItemID)
        if !success {
            manualQueueItemIDs = previousManualIDs
            sessionEnqueuedItems = previousSession
            queue = previousQueue
            setErrorBannerText("Kunde inte spela låten", "Det gick inte att hoppa till låten i kön")
        }
    }
}
