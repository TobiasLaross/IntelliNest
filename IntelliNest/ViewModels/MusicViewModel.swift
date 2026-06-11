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
    /// The playlist the user drilled into (nil = showing the result list). Tapping
    /// a playlist opens it here instead of playing it immediately.
    @Published var openedPlaylist: MusicSearchItem?
    @Published var playlistTracks: [MusicPlaylistTrack] = []
    @Published var isLoadingPlaylist = false
    /// The user's favourite Spotify playlists, shown for quick launch in place of
    /// the speaker list. Loaded on the first reload.
    @Published var favoritePlaylists: [MusicSearchItem] = []
    /// The most recently played playlists (Music Assistant `last_played` order),
    /// shown above the favourites. Refreshed whenever a playlist is launched.
    @Published var recentlyPlayedPlaylists: [MusicSearchItem] = []
    /// A library playlist the user opened to browse from the main view (favourites
    /// or recents), presented in its own sheet. Nil when no browse sheet is shown.
    @Published var browsingLibraryPlaylist: MusicSearchItem?

    var isReloading = false
    private var hasSelectedDefaultSpeaker = false
    /// Read/written by the library-playlist loader in `MusicViewModel+Playback`.
    var hasLoadedLibrary = false
    /// Increments on every search so a slow, older response can't overwrite the
    /// results of a newer query.
    private var searchRequestToken = 0

    /// Injected dependencies — internal (not private) so the playback/playlist
    /// methods extracted into `MusicViewModel+Playback` can reach them.
    let restAPIService: RestAPIService
    let setErrorBannerText: StringStringClosure

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
        await loadLibraryPlaylistsIfNeeded()
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
        openedPlaylist = nil
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

    // MARK: - Group volume

    /// The speakers currently synced with the active speaker (leader plus any
    /// followers), in the fixed display order. When the active speaker is
    /// ungrouped this is just the active speaker on its own.
    var groupedSpeakers: [MediaPlayerEntity] {
        guard let activeSpeaker else {
            return []
        }
        let memberIDs = activeSpeaker.groupMembers
        guard memberIDs.count > 1 else {
            return [activeSpeaker]
        }
        return Self.speakerIDs.filter { memberIDs.contains($0) }.compactMap { speakers[$0] }
    }

    /// Whether the active speaker is synced with at least one other speaker, so
    /// the volume control should act on the whole group.
    var isGroupActive: Bool {
        groupedSpeakers.count > 1
    }

    /// The single value shown on the group-volume banner: the average volume
    /// across every grouped speaker.
    var groupVolume: Double {
        let grouped = groupedSpeakers
        guard grouped.isNotEmpty else {
            return 0
        }
        let total = grouped.reduce(0.0) { $0 + $1.volumeLevel }
        return total / Double(grouped.count)
    }

    /// Sets every grouped speaker to the same absolute volume. Individual
    /// speakers can still be rebalanced afterwards via their own sliders.
    func setGroupVolume(_ volume: Double) {
        for speaker in groupedSpeakers {
            setVolume(volume, for: speaker.entityId)
        }
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
