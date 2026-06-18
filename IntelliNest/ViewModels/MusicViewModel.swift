//
//  MusicViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import Foundation

/// A personal account's section of playlists, ready to render. The `title` is
/// the owner's name ("Tobias spellistor", "Sarahs spellistor"), so it's stored
/// rather than derived from the account.
struct PersonalPlaylistSection: Identifiable, Equatable {
    let account: SpotifyPersonalAccount
    let title: String
    let playlists: [MusicSearchItem]

    var id: String { account.id }
}

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

    /// Maps four of the controllable speakers to their native Sonos hardware
    /// entity (same physical device). The two AirPlay rooms (outdoor table, spa)
    /// have no separate hardware entity and so can't diverge — they're absent here.
    static let hardwareTwinIDs: [EntityId: EntityId] = [
        .mediaPlayerLivingRoom: .mediaPlayerLivingRoomSonos,
        .mediaPlayerKitchen: .mediaPlayerKitchenSonos,
        .mediaPlayerGuestRoom: .mediaPlayerGuestRoomSonos,
        .mediaPlayerPlayroom: .mediaPlayerPlayroomSonos
    ]

    @Published var speakers: [EntityId: MediaPlayerEntity]
    /// The native Sonos hardware entities, keyed by the Music Assistant speaker
    /// they back. Read as the source of truth for the now-playing display when the
    /// MA queue entity has gone stale (playback started outside the app's queue).
    @Published var hardwareTwins: [EntityId: MediaPlayerEntity] = [:]
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
    /// The playlists favourited in Music Assistant (`library://playlist/<id>`
    /// items). Drives the favourite-star fill (matched by name) and carries the
    /// library id needed to unfavourite over the socket. With MA's Spotify 2-way
    /// sync on, this mirrors what the huset account follows on Spotify.
    @Published var maFavorites: [MusicSearchItem] = []
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
    /// Queue-item ids of tracks the user enqueued by hand (play next / add to
    /// queue): synthetic session ids before the live queue is read, real server
    /// ids after reconciliation. Drives the "I kö" grouping on the Queue screen.
    /// Music Assistant's queue carries no origin marker, so the app tracks this
    /// itself. Reconciled against the live queue on each load. Tracked per session
    /// only — like `nowPlayingSourcePlaylist`, the grouping resets after a relaunch
    /// rather than risk mislabelling playlist tracks from stale persisted state.
    var manualQueueItemIDs: Set<String> = []
    /// Monotonic sequence for synthetic session-item ids. Never decreases, so a
    /// remove-then-re-add of the same track can't reuse an id still in the list
    /// (a plain count would collide).
    var sessionEnqueueSequence = 0
    /// One section per configured personal account that currently has public
    /// playlists, in configured order, rendered below "Favoriter". Accounts with
    /// no playlists (empty/failed fetch, or logged out) are kept off the list.
    @Published var personalPlaylistSections: [PersonalPlaylistSection] = []
    /// Speakers with an in-flight join/unjoin. Home Assistant applies a group
    /// change a beat after the call returns, so each grouping row shows a small
    /// spinner while its speaker is in this set — bridging the gap between the tap
    /// and the refreshed membership. Mutated by the grouping calls in
    /// `MusicViewModel+Grouping`.
    @Published var pendingGroupingSpeakers: Set<EntityId> = []

    var isReloading = false
    private var hasSelectedDefaultSpeaker = false
    /// Read/written by the library-playlist loader in `MusicViewModel+Playback`.
    var hasLoadedLibrary = false
    /// Guards the one-time load of the Spotify account's playlists. Reset after a
    /// favourite toggle so the favourites section reflects the change next reload.
    var hasLoadedSpotifyPlaylists = false
    /// Guards the one-time Spotify-library → MA-favourite sync so it runs once per
    /// session and can't re-add a playlist the user just unstarred.
    var hasSyncedSpotifyFavorites = false
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
    /// The personal accounts whose public playlists are surfaced as their own
    /// sections. Injectable so tests can exercise multiple-account ordering and the
    /// hide-when-empty rule without depending on the baked-in list.
    let personalAccounts: [SpotifyPersonalAccount]
    /// The logged-in app user, read when building the personal sections so the
    /// viewer's own playlists are shown first (each section is titled by its
    /// owner's name). Injected as a closure so tests don't depend on shared
    /// `UserDefaults`.
    let currentUser: @MainActor () -> User
    /// Reads/writes the last speaker the user controlled, so it can be
    /// pre-selected when the music view next opens. Injected as closures so tests
    /// don't depend on shared `UserDefaults`.
    let loadLastSpeaker: @MainActor () -> EntityId?
    let saveLastSpeaker: @MainActor (EntityId) -> Void

    /// Speakers that are reachable right now (anything not `unavailable`), in the
    /// fixed display order, each mirroring its hardware twin so the now-playing
    /// metadata and play indicator reflect what's actually audible. Safe for the
    /// picker, grouping, and default-selection: the mirror only touches display
    /// fields, leaving id, group members, and volume from the MA entity.
    var availableSpeakers: [MediaPlayerEntity] {
        Self.speakerIDs.compactMap { displayedSpeaker($0) }.filter { !$0.isUnavailable }
    }

    /// The raw Music Assistant entity for the active speaker. Used by the playback,
    /// grouping, and volume commands, which must target the MA entity — not the
    /// mirrored display copy. The now-playing card reads `displayedActiveSpeaker`.
    var activeSpeaker: MediaPlayerEntity? {
        guard let activeSpeakerID else {
            return nil
        }
        return speakers[activeSpeakerID]
    }

    /// The active speaker as it should be shown: the MA entity mirroring its
    /// hardware twin. Drives the now-playing card's track, art, and play/pause
    /// state so they stay honest when playback was started outside the app.
    var displayedActiveSpeaker: MediaPlayerEntity? {
        guard let activeSpeakerID else {
            return nil
        }
        return displayedSpeaker(activeSpeakerID)
    }

    /// A speaker mirrored against its hardware twin (when it has one). Returns the
    /// MA entity unchanged for the AirPlay rooms or when the twin is idle.
    func displayedSpeaker(_ speakerID: EntityId) -> MediaPlayerEntity? {
        guard let speaker = speakers[speakerID] else {
            return nil
        }
        return speaker.mirroring(hardwareTwins[speakerID])
    }

    init(restAPIService: RestAPIService,
         setErrorBannerText: @escaping StringStringClosure = { _, _ in },
         spotify: SpotifyPlaylistService = DisabledSpotifyPlaylistService(),
         queueSocket: MusicAssistantQueueSocket = DisabledMusicAssistantQueueSocket(),
         personalAccounts: [SpotifyPersonalAccount] = SpotifyPersonalAccount.configured,
         currentUser: @escaping @MainActor () -> User = { UserManager.currentUser },
         loadLastSpeaker: @escaping @MainActor () -> EntityId? = {
             UserDefaults.shared.string(forKey: StorageKeys.lastMusicSpeaker.rawValue).flatMap { EntityId(rawValue: $0) }
         },
         saveLastSpeaker: @escaping @MainActor (EntityId) -> Void = {
             UserDefaults.shared.set($0.rawValue, forKey: StorageKeys.lastMusicSpeaker.rawValue)
         }) {
        self.restAPIService = restAPIService
        self.setErrorBannerText = setErrorBannerText
        self.spotify = spotify
        self.queueSocket = queueSocket
        self.personalAccounts = personalAccounts
        self.currentUser = currentUser
        self.loadLastSpeaker = loadLastSpeaker
        self.saveLastSpeaker = saveLastSpeaker
        isSpotifyAuthorized = spotify.isAuthorized
        var initialSpeakers: [EntityId: MediaPlayerEntity] = [:]
        for speakerID in Self.speakerIDs {
            initialSpeakers[speakerID] = MediaPlayerEntity(entityId: speakerID)
        }
        speakers = initialSpeakers
    }

    func reload() async {
        await withReloadGuard {
            await self.reloadSpeakers()
            self.selectDefaultSpeakerIfNeeded()
            self.dropActiveSpeakerIfUnavailable()
            self.dropSourcePlaylistIfDiverged()
        }
        await loadLibraryPlaylistsIfNeeded()
        await refreshQueueIfShowing()
    }

    /// Re-fetches every speaker entity in parallel and republishes it. Split out
    /// from `reload()` so a grouping change (in `MusicViewModel+Grouping`) can
    /// confirm the new membership right away instead of waiting for the next
    /// 5-second loop.
    func reloadSpeakers() async {
        let service = restAPIService
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
        await reloadHardwareTwins()
    }

    /// Re-fetches the native Sonos entities that back the four Sonos rooms, keyed
    /// by the Music Assistant speaker they belong to. A failed fetch drops that
    /// twin (the room then falls back to the MA entity's own now-playing) rather
    /// than blocking the rest of the reload.
    private func reloadHardwareTwins() async {
        let service = restAPIService
        await withTaskGroup(of: (EntityId, MediaPlayerEntity)?.self) { group in
            for (speakerID, twinID) in Self.hardwareTwinIDs {
                group.addTask {
                    do {
                        let twin = try await service.reload(entityId: twinID, entityType: MediaPlayerEntity.self)
                        return (speakerID, twin)
                    } catch {
                        Log.error("Failed to reload hardware twin: \(twinID): \(error)")
                        return nil
                    }
                }
            }

            for await result in group {
                if let (speakerID, twin) = result {
                    self.hardwareTwins[speakerID] = twin
                }
            }
        }
    }

    /// On the first reload after the view appears, default the active speaker to
    /// whatever is currently playing, falling back to the last speaker the user
    /// controlled (if it's reachable). If neither applies, leave it unselected so
    /// the picker is shown. Runs only once so it never overrides a manual pick.
    private func selectDefaultSpeakerIfNeeded() {
        guard !hasSelectedDefaultSpeaker else {
            return
        }
        hasSelectedDefaultSpeaker = true
        if let playing = availableSpeakers.first(where: { $0.isPlaying }) {
            activeSpeakerID = playing.entityId
        } else if let lastUsed = loadLastSpeaker(),
                  availableSpeakers.contains(where: { $0.entityId == lastUsed }) {
            activeSpeakerID = lastUsed
        }
    }

    private func dropActiveSpeakerIfUnavailable() {
        if let activeSpeakerID, speakers[activeSpeakerID]?.isUnavailable == true {
            self.activeSpeakerID = nil
        }
    }

    /// Clears the "Spelas från <spellista>" breadcrumb once the active speaker's
    /// hardware twin reports a different track than the Music Assistant queue. That
    /// happens when playback was taken over from outside the app — the in-app
    /// playlist the breadcrumb points at is no longer what's playing, so jumping to
    /// it would mislead.
    private func dropSourcePlaylistIfDiverged() {
        guard nowPlayingSourcePlaylist != nil,
              let activeSpeakerID,
              let speaker = speakers[activeSpeakerID],
              let twin = hardwareTwins[activeSpeakerID],
              twin.hasLiveAudio,
              !twin.isSameTrack(as: speaker) else {
            return
        }
        nowPlayingSourcePlaylist = nil
    }

    func selectSpeaker(_ entityID: EntityId) {
        activeSpeakerID = entityID
        saveLastSpeaker(entityID)
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
}
