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
        let passed = queue.upcomingItems[...index]

        manualQueueItemIDs.subtract(passed.map(\.id))
        let optimisticQueue = MusicQueue(queueID: queueID,
                                         currentItem: item,
                                         upcomingItems: Array(queue.upcomingItems[(index + 1)...]),
                                         manualItemIDs: manualQueueItemIDs)
        queue = optimisticQueue

        let success = await queueSocket.playItem(queueID: queueID, itemID: item.queueItemID)
        guard success else {
            // Put back only the ids the jump dropped, so a track queued while the
            // command was in flight keeps its "I kö" grouping.
            manualQueueItemIDs.formUnion(previousManualIDs.intersection(passed.map(\.id)))
            if queue == optimisticQueue {
                queue = MusicQueue(queueID: previousQueue.queueID,
                                   currentItem: previousQueue.currentItem,
                                   upcomingItems: previousQueue.upcomingItems,
                                   manualItemIDs: manualQueueItemIDs)
            } else {
                // Something else changed the queue meanwhile; restoring the snapshot
                // would discard that, so re-read the live queue instead.
                await loadQueue()
            }
            setErrorBannerText("Kunde inte spela låten", "Det gick inte att hoppa till låten i kön")
            return
        }
        // Passed manual tracks are no longer upcoming, so their session fallback
        // rows must not resurface on an offline reload. Only manual ones: a context
        // track sharing a uri with a later session add must not take that row.
        for passedItem in passed where previousManualIDs.contains(passedItem.id) {
            removeSessionRow(matching: passedItem)
        }
    }
}
