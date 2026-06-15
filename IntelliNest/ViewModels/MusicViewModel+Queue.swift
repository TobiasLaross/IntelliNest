//
//  MusicViewModel+Queue.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import Foundation

/// Where a newly-added track lands in the queue, mapped to Music Assistant's
/// `enqueue` modes: `.next` plays it right after the current track, `.last`
/// appends it to the end.
enum QueuePlacement {
    case next
    case last

    var enqueueMode: String {
        switch self {
        case .next: "next"
        case .last: "add"
        }
    }
}

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

        let state: MusicQueueState
        do {
            state = try await restAPIService.getQueue(on: targetID)
        } catch {
            Log.error("Failed to read queue: \(error)")
            state = .empty
        }

        let currentItem = state.currentItem ?? currentItemFromSpeaker()
        let upcoming = await upcomingItems(queueID: state.queueID, currentItem: currentItem, nextItem: state.nextItem)
        queue = MusicQueue(queueID: state.queueID,
                           currentItem: currentItem,
                           upcomingItems: upcoming,
                           manualItemIDs: manualQueueItemIDs)
    }

    /// The upcoming tracks: the socket's full ordered list sliced to whatever
    /// follows the current item, falling back to the REST-supplied next item plus
    /// anything enqueued this session when the socket returns nothing (the socket
    /// is LAN-only, so it's unreachable away from home).
    private func upcomingItems(queueID: String?,
                               currentItem: MusicQueueItem?,
                               nextItem: MusicQueueItem?) async -> [MusicQueueItem] {
        guard let queueID else {
            return offlineUpcoming(nextItem: nextItem)
        }
        let items = await queueSocket.queueItems(queueID: queueID)
        guard items.isNotEmpty else {
            return offlineUpcoming(nextItem: nextItem)
        }
        let upcoming: [MusicQueueItem] = if let currentItem,
                                            let currentIndex = items.firstIndex(where: { $0.queueItemID == currentItem.queueItemID }) {
            Array(items[(currentIndex + 1)...])
        } else {
            // Current track not located in the list — show the whole list rather
            // than nothing, minus any entry that is the current track by uri.
            items.filter { $0.uri == nil || $0.uri != currentItem?.uri }
        }
        reconcileManualIDs(against: upcoming)
        return upcoming
    }

    /// Re-anchors the manual-queue id set to the live queue. Music Assistant gives
    /// queued items no origin marker, so the synthetic session ids vanish once the
    /// socket returns real server items. This keeps the real ids already known to
    /// be manual (that still exist), then claims one live item per session-enqueued
    /// uri not yet represented — matching by uri, each session add consuming one
    /// row. Ids no longer in the queue (removed, or wiped by a new playlist) drop
    /// out, so "I kö" keeps pointing at the right rows.
    private func reconcileManualIDs(against upcoming: [MusicQueueItem]) {
        let upcomingIDs = Set(upcoming.map(\.id))
        var reconciled = manualQueueItemIDs.intersection(upcomingIDs)
        var unclaimed = upcoming.filter { !reconciled.contains($0.id) }
        for sessionItem in sessionEnqueuedItems {
            guard let uri = sessionItem.uri,
                  let matchIndex = unclaimed.firstIndex(where: { $0.uri == uri }) else {
                continue
            }
            reconciled.insert(unclaimed[matchIndex].id)
            unclaimed.remove(at: matchIndex)
        }
        manualQueueItemIDs = reconciled
    }

    /// The "Näst på tur" list when the socket can't supply the full queue: at least
    /// the immediate next track (from `get_queue` over REST, which works remotely),
    /// then anything enqueued this session, never showing the next track twice.
    private func offlineUpcoming(nextItem: MusicQueueItem?) -> [MusicQueueItem] {
        guard let nextItem else {
            return sessionEnqueuedItems
        }
        let rest = sessionEnqueuedItems.filter { $0.uri == nil || $0.uri != nextItem.uri }
        return [nextItem] + rest
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

    /// Forgets the manual-queue tracking (the "I kö" grouping and its session
    /// fallback). Called when the queue is replaced wholesale, since the previous
    /// manual adds are gone from the server queue.
    func clearManualQueueTracking() {
        manualQueueItemIDs = []
        sessionEnqueuedItems = []
        // Also drop the grouping on the already-published queue, so nothing shows
        // under "I kö" in the window before the next loadQueue() rebuilds it.
        queue = MusicQueue(queueID: queue.queueID,
                           currentItem: queue.currentItem,
                           upcomingItems: queue.upcomingItems,
                           manualItemIDs: [])
    }

    // MARK: - Add

    func addToQueue(_ track: MusicPlaylistTrack, placement: QueuePlacement = .last) async {
        await addToQueue(uri: track.uri, title: track.title, artist: nil, imageURL: track.imageURL, placement: placement)
    }

    func addToQueue(_ item: MusicSearchItem, placement: QueuePlacement = .last) async {
        await addToQueue(uri: item.uri, title: item.name, artist: item.artist, imageURL: item.imageURL, placement: placement)
    }

    /// Adds a track to the active speaker's queue, either right after the current
    /// track (`.next`) or at the end (`.last`). Optimistically inserts it into
    /// "Näst på tur" and the session fallback; banners on failure. This goes over
    /// REST (`play_media`), so it works away from home too — unlike reading the
    /// full upcoming list, which needs the LAN-only socket.
    func addToQueue(uri: String, title: String, artist: String?, imageURL: String?, placement: QueuePlacement = .last) async {
        guard let targetID = queueTargetID else {
            setErrorBannerText("Ingen högtalare vald", "Välj en högtalare innan du lägger till i kön")
            return
        }
        let success = await restAPIService.playMedia(on: targetID, mediaID: uri, mediaType: .track, enqueue: placement.enqueueMode)
        guard success else {
            setErrorBannerText("Kunde inte lägga till i kön", "Det gick inte att lägga till låten i kön")
            return
        }
        // A session-local id: these fallback rows have no server queue-item id,
        // so they are removed locally only. A queue reload replaces them with the
        // real items once the socket can read the live queue.
        let sessionItem = MusicQueueItem(queueItemID: "session-\(sessionEnqueueSequence)-\(uri)",
                                         uri: uri,
                                         title: title,
                                         artist: artist,
                                         imageURL: imageURL)
        sessionEnqueueSequence += 1
        // The user added this by hand, so it belongs in "I kö" — track its id now;
        // reconciliation swaps the synthetic id for the real one on the next load.
        manualQueueItemIDs.insert(sessionItem.id)
        switch placement {
        case .next:
            sessionEnqueuedItems.insert(sessionItem, at: 0)
            queue = MusicQueue(queueID: queue.queueID,
                               currentItem: queue.currentItem,
                               upcomingItems: [sessionItem] + queue.upcomingItems,
                               manualItemIDs: manualQueueItemIDs)
        case .last:
            sessionEnqueuedItems.append(sessionItem)
            queue = MusicQueue(queueID: queue.queueID,
                               currentItem: queue.currentItem,
                               upcomingItems: queue.upcomingItems + [sessionItem],
                               manualItemIDs: manualQueueItemIDs)
        }
    }

    // MARK: - Remove

    /// Removes an upcoming track from the queue. Optimistically drops it, then
    /// deletes it over the socket when it is a real (server-backed) queue item;
    /// session-fallback rows have no server id and are removed locally only.
    /// Reverts and banners if the socket delete fails.
    func removeFromQueue(_ item: MusicQueueItem) async {
        let previousUpcoming = queue.upcomingItems
        let previousSession = sessionEnqueuedItems
        let previousManualIDs = manualQueueItemIDs
        let isSessionOnly = previousSession.contains { $0.id == item.id }

        manualQueueItemIDs.remove(item.id)
        queue = MusicQueue(queueID: queue.queueID,
                           currentItem: queue.currentItem,
                           upcomingItems: previousUpcoming.filter { $0.id != item.id },
                           manualItemIDs: manualQueueItemIDs)
        removeSessionRow(matching: item)

        guard let queueID = queue.queueID, !isSessionOnly else {
            return
        }
        let success = await queueSocket.deleteItem(queueID: queueID, itemID: item.queueItemID)
        if !success {
            manualQueueItemIDs = previousManualIDs
            queue = MusicQueue(queueID: queue.queueID,
                               currentItem: queue.currentItem,
                               upcomingItems: previousUpcoming,
                               manualItemIDs: manualQueueItemIDs)
            sessionEnqueuedItems = previousSession
            setErrorBannerText("Kunde inte ta bort från kön", "Det gick inte att ta bort låten från kön")
        }
    }

    /// Drops the session-fallback row backing a removed item. Matches on the
    /// synthetic id first; once an add has been reconciled, the live item carries
    /// the real server id instead, so fall back to removing one row with the same
    /// uri — otherwise the stale placeholder would linger in the offline fallback.
    private func removeSessionRow(matching item: MusicQueueItem) {
        if let index = sessionEnqueuedItems.firstIndex(where: { $0.id == item.id }) {
            sessionEnqueuedItems.remove(at: index)
        } else if let uri = item.uri, let index = sessionEnqueuedItems.firstIndex(where: { $0.uri == uri }) {
            sessionEnqueuedItems.remove(at: index)
        }
    }
}
