//
//  MusicViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import Foundation

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
    /// URIs of playlists currently saved in the user's Spotify library, driving the
    /// star toggle in the playlist detail view. Populated on demand per playlist.
    @Published var savedPlaylistURIs: Set<String> = []
    /// Whether the user is logged into Spotify. Drives the login warning triangle
    /// and its prompt — shown only while logged out.
    @Published var isSpotifyAuthorized = false
    /// The playlist the current track is playing from, when playback was started
    /// from a playlist within the app this session. Drives the now-playing card's
    /// jump-to-playlist tap. Nil when the source is unknown (started elsewhere, a
    /// single track played, or after relaunch), which hides the affordance.
    @Published var nowPlayingSourcePlaylist: MusicSearchItem?
    /// URIs of tracks currently in the user's Spotify Liked Songs, driving the
    /// song favourite star wherever a track is shown. Loaded on demand per view.
    @Published var savedSongURIs: Set<String> = []
    /// Spotify ids of the account playlists the user can edit (owned or
    /// collaborative). Gates the add-to-playlist picker and the remove action.
    @Published var editablePlaylistSpotifyIDs: Set<String> = []
    /// The queue shown on the Queue screen: the current track and the upcoming
    /// tracks for the active speaker's group leader.
    @Published var queue: MusicQueue = .empty
    @Published var isLoadingQueue = false
    /// Drives the Queue sheet presented from the now-playing area.
    @Published var isShowingQueue = false
    /// Tracks the app enqueued this session, newest last. Used as the "Näst på
    /// tur" fallback when the live queue contents can't be read over the socket.
    @Published var sessionEnqueuedItems: [MusicQueueItem] = []

    var isReloading = false
    private var hasSelectedDefaultSpeaker = false
    /// Read/written by the library-playlist loader in `MusicViewModel+Playback`.
    var hasLoadedLibrary = false
    /// Guards the one-time load of the Spotify account's playlists. Reset after a
    /// favourite toggle so the favourites section reflects the change next reload.
    var hasLoadedSpotifyPlaylists = false
    /// Increments on every search so a slow, older response can't overwrite the
    /// results of a newer query.
    private var searchRequestToken = 0

    /// Injected dependencies — internal (not private) so the playback/playlist
    /// methods extracted into `MusicViewModel+Playback` can reach them.
    let restAPIService: RestAPIService
    let setErrorBannerText: StringStringClosure
    /// Reads the account's playlists and saves/removes playlists in the user's
    /// Spotify library. Defaults to a disabled no-op so previews and non-Spotify
    /// tests need no setup.
    let spotify: SpotifyPlaylistService
    /// Reads and edits the Music Assistant queue over its WebSocket (the commands
    /// Home Assistant exposes no REST service for). Defaults to a disabled no-op
    /// so previews and tests need no socket.
    let queueSocket: MusicAssistantQueueSocket

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

    init(restAPIService: RestAPIService,
         setErrorBannerText: @escaping StringStringClosure = { _, _ in },
         spotify: SpotifyPlaylistService = DisabledSpotifyPlaylistService(),
         queueSocket: MusicAssistantQueueSocket = DisabledMusicAssistantQueueSocket()) {
        self.restAPIService = restAPIService
        self.setErrorBannerText = setErrorBannerText
        self.spotify = spotify
        self.queueSocket = queueSocket
        isSpotifyAuthorized = spotify.isAuthorized
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
        await refreshQueueIfShowing()
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
    /// speaker stays the group leader (the `join` sync source). Surfaces an error
    /// banner when Home Assistant rejects the group change, so a failed sync no
    /// longer looks like a silent no-op.
    func toggleGroupMember(_ speakerID: EntityId) async {
        guard let activeSpeakerID, speakerID != activeSpeakerID else {
            return
        }
        let speakerName = speakers[speakerID]?.friendlyName ?? speakerID.rawValue
        if isGrouped(speakerID) {
            let success = await restAPIService.unjoinSpeaker(memberID: speakerID)
            if !success {
                setErrorBannerText("Kunde inte dela upp högtalare", "Det gick inte att ta bort \(speakerName) från gruppen")
            }
        } else {
            // A speaker already synced into a different group (e.g. Spa paired with
            // Matbord-ute) can't be moved by a plain join, so unjoin it from its
            // current group first. groupMembers > 1 means it is grouped with someone
            // other than the active leader, since the grouped-with-leader case is the
            // unjoin branch above.
            let isInOtherGroup = (speakers[speakerID]?.groupMembers.count ?? 0) > 1
            let success = await restAPIService.joinSpeakers(leaderID: activeSpeakerID,
                                                            memberIDs: [speakerID],
                                                            unjoinFirst: isInOtherGroup)
            if !success {
                setErrorBannerText("Kunde inte gruppera högtalare", "Det gick inte att lägga till \(speakerName) i gruppen")
            }
        }
    }
}
