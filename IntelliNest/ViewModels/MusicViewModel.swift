//
//  MusicViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import Foundation
import ShipBookSDK

@MainActor
class MusicViewModel: ObservableObject, Reloadable {
    /// The six controllable Music Assistant speakers, in display order.
    static let speakerIDs: [EntityId] = [
        .mediaPlayerKitchen,
        .mediaPlayerGuestRoom,
        .mediaPlayerPlayroom,
        .mediaPlayerLivingRoom,
        .mediaPlayerOutdoorTable,
        .mediaPlayerSpa
    ]

    @Published var speakers: [EntityId: MediaPlayerEntity]
    @Published var activeSpeakerID: EntityId?
    @Published var searchText = ""
    @Published var searchSections: [MusicSearchSection] = []
    @Published var hasSearched = false
    @Published var isSearching = false
    /// Drives the search-results sheet, which presents the grouped results in a
    /// separate view with a tab per media-type category.
    @Published var isShowingSearchResults = false

    var isReloading = false
    private var hasSelectedDefaultSpeaker = false
    /// Increments on every search so a slow, older response can't overwrite the
    /// results of a newer query.
    private var searchRequestToken = 0

    private let restAPIService: RestAPIService
    private let setErrorBannerText: StringStringClosure

    /// Speakers that are reachable right now (anything not `unavailable`),
    /// in the fixed display order.
    var availableSpeakers: [MediaPlayerEntity] {
        Self.speakerIDs.compactMap { speakers[$0] }.filter { !$0.isUnavailable }
    }

    var activeSpeaker: MediaPlayerEntity? {
        guard let activeSpeakerID else {
            return nil
        }
        return speakers[activeSpeakerID]
    }

    init(restAPIService: RestAPIService, setErrorBannerText: @escaping StringStringClosure = { _, _ in }) {
        self.restAPIService = restAPIService
        self.setErrorBannerText = setErrorBannerText
        var initialSpeakers: [EntityId: MediaPlayerEntity] = [:]
        for speakerID in Self.speakerIDs {
            initialSpeakers[speakerID] = MediaPlayerEntity(entityId: speakerID)
        }
        speakers = initialSpeakers
    }

    func reload() async {
        await withReloadGuard {
            let service = self.restAPIService
            await withTaskGroup(of: (EntityId, MediaPlayerEntity)?.self) { group in
                for speakerID in Self.speakerIDs {
                    group.addTask {
                        do {
                            let speaker = try await service.reload(entityId: speakerID, entityType: MediaPlayerEntity.self)
                            return (speakerID, speaker)
                        } catch {
                            Log.error("Failed to reload speaker: \(speakerID): \(error)")
                            return nil
                        }
                    }
                }

                for await result in group {
                    if let (speakerID, speaker) = result {
                        self.speakers[speakerID] = speaker
                    }
                }
            }

            self.selectDefaultSpeakerIfNeeded()
            self.dropActiveSpeakerIfUnavailable()
        }
    }

    /// On the first reload after the view appears, default the active speaker to
    /// whatever is currently playing. If nothing is playing, leave it unselected
    /// so the picker is shown. Runs only once so it never overrides a manual pick.
    private func selectDefaultSpeakerIfNeeded() {
        guard !hasSelectedDefaultSpeaker else {
            return
        }
        hasSelectedDefaultSpeaker = true
        if let playing = availableSpeakers.first(where: { $0.isPlaying }) {
            activeSpeakerID = playing.entityId
        }
    }

    private func dropActiveSpeakerIfUnavailable() {
        if let activeSpeakerID, speakers[activeSpeakerID]?.isUnavailable == true {
            self.activeSpeakerID = nil
        }
    }

    func selectSpeaker(_ entityID: EntityId) {
        activeSpeakerID = entityID
    }

    // MARK: - Search

    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isNotEmpty else {
            searchSections = []
            hasSearched = false
            return
        }

        searchRequestToken += 1
        let token = searchRequestToken
        isShowingSearchResults = true
        isSearching = true
        hasSearched = true
        do {
            let response = try await restAPIService.searchMusic(query: query)
            guard token == searchRequestToken else {
                return
            }
            searchSections = response.sections
        } catch {
            guard token == searchRequestToken else {
                return
            }
            Log.error("Music search failed: \(error)")
            // Don't leave the UI in a "no results" state — close the results
            // sheet and surface the failure through the error banner instead.
            searchSections = []
            hasSearched = false
            isShowingSearchResults = false
            setErrorBannerText("Sökningen misslyckades", "Kunde inte söka efter musik")
        }
        if token == searchRequestToken {
            isSearching = false
        }
    }

    var hasNoResults: Bool {
        hasSearched && !isSearching && searchSections.isEmpty
    }

    // MARK: - Playback

    /// Playback and queue commands must go to the active speaker's group leader;
    /// a synced follower rejects them. Returns the active speaker itself when it
    /// is ungrouped. Volume stays per-speaker, so it is not redirected here.
    private var playbackTargetID: EntityId? {
        guard let activeSpeaker else {
            return activeSpeakerID
        }
        return activeSpeaker.playbackTargetID
    }

    func play(item: MusicSearchItem) async {
        guard let activeSpeakerID, let targetID = playbackTargetID else {
            setErrorBannerText("Ingen högtalare vald", "Välj en högtalare innan du spelar musik")
            return
        }

        let success = await restAPIService.playMedia(on: targetID,
                                                     mediaID: item.uri,
                                                     mediaType: item.mediaType)
        if success {
            // Optimistically reflect what we just started; a reload confirms it.
            speakers[activeSpeakerID]?.state = "playing"
            speakers[activeSpeakerID]?.mediaTitle = item.name
            speakers[activeSpeakerID]?.mediaArtist = item.artist
            restAPIService.triggerRepeatReload(times: 3)
        } else {
            setErrorBannerText("Kunde inte spela", "Det gick inte att starta uppspelningen")
        }
    }

    func togglePlayPause() {
        guard let activeSpeaker, let targetID = playbackTargetID else {
            return
        }
        let action: Action = activeSpeaker.isPlaying ? .mediaPause : .mediaPlay
        speakers[activeSpeaker.entityId]?.state = activeSpeaker.isPlaying ? "paused" : "playing"
        restAPIService.mediaTransport(entityID: targetID, action: action)
    }

    func nextTrack() {
        guard let targetID = playbackTargetID else {
            return
        }
        restAPIService.mediaTransport(entityID: targetID, action: .mediaNextTrack)
    }

    func previousTrack() {
        guard let targetID = playbackTargetID else {
            return
        }
        restAPIService.mediaTransport(entityID: targetID, action: .mediaPreviousTrack)
    }

    func setVolume(_ volume: Double) {
        guard let activeSpeakerID else {
            return
        }
        speakers[activeSpeakerID]?.volumeLevel = volume
        restAPIService.setVolume(entityID: activeSpeakerID, volume: volume)
    }

    func toggleShuffle() {
        guard let activeSpeaker, let targetID = playbackTargetID else {
            return
        }
        let newValue = !activeSpeaker.shuffle
        speakers[activeSpeaker.entityId]?.shuffle = newValue
        restAPIService.setShuffle(entityID: targetID, shuffle: newValue)
    }

    func toggleRepeat() {
        guard let activeSpeaker, let targetID = playbackTargetID else {
            return
        }
        // Cycle off → all → one → off, matching the Sonos-style three-state control.
        let newMode: MediaRepeatMode = switch activeSpeaker.repeatMode {
        case .off: .all
        case .all: .one
        case .one: .off
        }
        speakers[activeSpeaker.entityId]?.repeatMode = newMode
        restAPIService.setRepeat(entityID: targetID, repeatMode: newMode)
    }

    // MARK: - Grouping

    /// Whether `speakerID` is currently grouped with the active speaker.
    func isGrouped(_ speakerID: EntityId) -> Bool {
        guard let activeSpeaker, speakerID != activeSpeaker.entityId else {
            return false
        }
        return activeSpeaker.groupMembers.contains(speakerID)
    }

    /// Toggles `speakerID` into or out of the active speaker's group. The active
    /// speaker stays the group leader (the `join` sync source).
    func toggleGroupMember(_ speakerID: EntityId) {
        guard let activeSpeakerID, speakerID != activeSpeakerID else {
            return
        }
        if isGrouped(speakerID) {
            restAPIService.unjoinSpeaker(memberID: speakerID)
        } else {
            restAPIService.joinSpeakers(leaderID: activeSpeakerID, memberIDs: [speakerID])
        }
    }
}
