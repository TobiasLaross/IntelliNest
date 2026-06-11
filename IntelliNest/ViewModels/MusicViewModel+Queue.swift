//
//  MusicViewModel+Queue.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import Foundation

/// The play queue for the active speaker's group leader. Reads run over two
/// transports: `music_assistant.get_queue` (REST) for the queue id and the
/// current track, and the Music Assistant WebSocket for the full upcoming list
/// and per-item removal — the two commands Home Assistant exposes no REST
/// service for. When the socket can't be reached the screen degrades to the
/// current track plus whatever the app enqueued this session.
extension MusicViewModel {
    /// The speaker whose queue is shown and acted on: the active speaker's group
    /// leader (a synced follower's queue mirrors the leader's).
    var queueTargetID: EntityId? {
        activeSpeaker?.playbackTargetID ?? activeSpeakerID
    }

    /// Opens the Queue sheet and loads its contents.
    func openQueue() async {
        isShowingQueue = true
        await loadQueue()
    }

    /// Refreshes the queue from the reload loop, but only while the sheet is open,
    /// so "Spelas nu" and "Näst på tur" stay current without extra work otherwise.
    func refreshQueueIfShowing() async {
        guard isShowingQueue else {
            return
        }
        await loadQueue()
    }

    /// Loads the current track and upcoming tracks for the active speaker's queue.
    func loadQueue() async {
        guard let targetID = queueTargetID else {
            queue = .empty
            return
        }
        isLoadingQueue = true
        defer { isLoadingQueue = false }

        let queueID: String?
        let restCurrent: MusicQueueItem?
        do {
            (queueID, restCurrent) = try await restAPIService.getQueue(on: targetID)
        } catch {
            Log.error("Failed to read queue: \(error)")
            (queueID, restCurrent) = (nil, nil)
        }

        let currentItem = restCurrent ?? currentItemFromSpeaker()
        let upcoming = await upcomingItems(queueID: queueID, currentItem: currentItem)
        queue = MusicQueue(queueID: queueID, currentItem: currentItem, upcomingItems: upcoming)
    }

    /// The upcoming tracks: the socket's full ordered list sliced to whatever
    /// follows the current item, or the session-enqueued fallback when the socket
    /// returns nothing (server unreachable, e.g. away from home).
    private func upcomingItems(queueID: String?, currentItem: MusicQueueItem?) async -> [MusicQueueItem] {
        guard let queueID else {
            return sessionEnqueuedItems
        }
        let items = await queueSocket.queueItems(queueID: queueID)
        guard items.isNotEmpty else {
            return sessionEnqueuedItems
        }
        guard let currentItem,
              let currentIndex = items.firstIndex(where: { $0.queueItemID == currentItem.queueItemID }) else {
            // Current track not located in the list — show the whole list rather
            // than nothing, minus any entry that is the current track by uri.
            return items.filter { $0.uri == nil || $0.uri != currentItem?.uri }
        }
        return Array(items[(currentIndex + 1)...])
    }

    /// Builds a "Spelas nu" item from the speaker's now-playing metadata, used
    /// when `get_queue` returns no current item.
    private func currentItemFromSpeaker() -> MusicQueueItem? {
        guard let speaker = activeSpeaker, let title = speaker.mediaTitle else {
            return nil
        }
        return MusicQueueItem(queueItemID: speaker.mediaContentID ?? "current",
                              uri: speaker.mediaContentID,
                              title: title,
                              artist: speaker.mediaArtist,
                              imageURL: speaker.entityPicture)
    }

    // MARK: - Add

    func addToQueue(_ track: MusicPlaylistTrack) async {
        await addToQueue(uri: track.uri, title: track.title, artist: nil, imageURL: track.imageURL)
    }

    func addToQueue(_ item: MusicSearchItem) async {
        await addToQueue(uri: item.uri, title: item.name, artist: item.artist, imageURL: item.imageURL)
    }

    /// Appends a track to the active speaker's queue. Optimistically adds it to
    /// "Näst på tur" and the session fallback; banners on failure.
    func addToQueue(uri: String, title: String, artist: String?, imageURL: String?) async {
        guard let targetID = queueTargetID else {
            setErrorBannerText("Ingen högtalare vald", "Välj en högtalare innan du lägger till i kön")
            return
        }
        let success = await restAPIService.playMedia(on: targetID, mediaID: uri, mediaType: .track, enqueue: "add")
        guard success else {
            setErrorBannerText("Kunde inte lägga till i kön", "Det gick inte att lägga till låten i kön")
            return
        }
        // A session-local id: these fallback rows have no server queue-item id,
        // so they are removed locally only. A queue reload replaces them with the
        // real items once the socket can read the live queue.
        let sessionItem = MusicQueueItem(queueItemID: "session-\(uri)-\(sessionEnqueuedItems.count)",
                                         uri: uri,
                                         title: title,
                                         artist: artist,
                                         imageURL: imageURL)
        sessionEnqueuedItems.append(sessionItem)
        queue = MusicQueue(queueID: queue.queueID,
                           currentItem: queue.currentItem,
                           upcomingItems: queue.upcomingItems + [sessionItem])
    }

    // MARK: - Remove

    /// Removes an upcoming track from the queue. Optimistically drops it, then
    /// deletes it over the socket when it is a real (server-backed) queue item;
    /// session-fallback rows have no server id and are removed locally only.
    /// Reverts and banners if the socket delete fails.
    func removeFromQueue(_ item: MusicQueueItem) async {
        let previousUpcoming = queue.upcomingItems
        let previousSession = sessionEnqueuedItems
        let isSessionOnly = previousSession.contains { $0.id == item.id }

        queue = MusicQueue(queueID: queue.queueID,
                           currentItem: queue.currentItem,
                           upcomingItems: previousUpcoming.filter { $0.id != item.id })
        sessionEnqueuedItems.removeAll { $0.id == item.id }

        guard let queueID = queue.queueID, !isSessionOnly else {
            return
        }
        let success = await queueSocket.deleteItem(queueID: queueID, itemID: item.queueItemID)
        if !success {
            queue = MusicQueue(queueID: queue.queueID, currentItem: queue.currentItem, upcomingItems: previousUpcoming)
            sessionEnqueuedItems = previousSession
            setErrorBannerText("Kunde inte ta bort från kön", "Det gick inte att ta bort låten från kön")
        }
    }
}
