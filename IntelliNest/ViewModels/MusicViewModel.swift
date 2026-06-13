//
//  MusicViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import Foundation

/// A personal account's section of playlists, ready to render. The `title` is
/// resolved per viewer ("Mina spellistor" for the logged-in user, the person's
/// name otherwise), so it's stored rather than derived from the account.
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
    /// One section per configured personal account that currently has public
    /// playlists, in configured order, rendered below "Favoriter". Accounts with
    /// no playlists (empty/failed fetch, or logged out) are kept off the list.
    @Published var personalPlaylistSections: [PersonalPlaylistSection] = []

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
    /// The personal accounts whose public playlists are surfaced as their own
    /// sections. Injectable so tests can exercise multiple-account ordering and the
    /// hide-when-empty rule without depending on the baked-in list.
    let personalAccounts: [SpotifyPersonalAccount]
    /// The logged-in app user, read when building the personal sections so the
    /// viewer's own playlists are shown first and titled "Mina spellistor".
    /// Injected as a closure so tests don't depend on shared `UserDefaults`.
    let currentUser: @MainActor () -> User
    /// Reads/writes the last speaker the user controlled, so it can be
    /// pre-selected when the music view next opens. Injected as closures so tests
    /// don't depend on shared `UserDefaults`.
    let loadLastSpeaker: @MainActor () -> EntityId?
    let saveLastSpeaker: @MainActor (EntityId) -> Void

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

    /// Promotes a grouped speaker to primary — the one shown and controlled as the
    /// group's main speaker. Playback still routes through the live Music Assistant
    /// group leader (`playbackTargetID`), so switching the primary never interrupts
    /// what's playing. No-op for a speaker that isn't grouped with the active one.
    func makePrimary(_ speakerID: EntityId) {
        guard speakerID != activeSpeakerID, isGrouped(speakerID) else {
            return
        }
        selectSpeaker(speakerID)
    }

    /// Removes the active (primary) speaker from its group and promotes the next
    /// grouped speaker to active, so playback control follows the speakers that
    /// keep playing. Music Assistant re-elects the real group leader on its own;
    /// the new `activeSpeakerID` only needs to be a remaining member, since
    /// playback commands are routed through the live group leader. No-op when the
    /// active speaker isn't grouped with anyone.
    func removeActiveSpeakerFromGroup() async {
        guard let activeSpeakerID, let activeSpeaker else {
            return
        }
        let remaining = Self.speakerIDs.filter { activeSpeaker.groupMembers.contains($0) && $0 != activeSpeakerID }
        guard let newActiveID = remaining.first else {
            return
        }
        let speakerName = activeSpeaker.friendlyName
        let success = await restAPIService.unjoinSpeaker(memberID: activeSpeakerID)
        if success {
            // Route through selectSpeaker so the promoted speaker is also persisted
            // as the last-used one, like any other manual selection.
            selectSpeaker(newActiveID)
        } else {
            setErrorBannerText("Kunde inte dela upp högtalare", "Det gick inte att ta bort \(speakerName) från gruppen")
        }
    }
}
