@testable import IntelliNest
import XCTest

/// A Spotify stub that records calls and tracks saved ids in memory, so the view
/// model's account-playlist load and optimistic toggle/revert logic can be tested
/// without Spotify.
@MainActor
final class StubSpotifyPlaylistService: SpotifyPlaylistService {
    var authorized: Bool
    var savedIDs: Set<String>
    var operationSucceeds: Bool
    var authorizeThrows: Bool
    var accountPlaylistItems: [MusicSearchItem]
    /// Public playlists keyed by Spotify user id, standing in for what
    /// `/users/<id>/playlists` returns. Empty by default, which is exactly how the
    /// real service behaves when Spotify refuses the read.
    var personalPlaylistsByUser: [String: [MusicSearchItem]]
    var editableIDs: Set<String>
    /// Makes the next account fetch log the user out, as a rejected refresh token does.
    var revokesOnFetch = false
    var savedSongTrackIDs: Set<String>
    private(set) var authorizeCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var accountPlaylistsCallCount = 0
    private(set) var personalPlaylistsCallCount = 0
    private(set) var saveSongCallCount = 0
    private(set) var removeSongCallCount = 0
    private(set) var addedTracks: [(playlistID: String, trackID: String)] = []
    private(set) var removedTracks: [(playlistID: String, trackID: String)] = []

    init(authorized: Bool = true,
         savedIDs: Set<String> = [],
         operationSucceeds: Bool = true,
         authorizeThrows: Bool = false,
         accountPlaylistItems: [MusicSearchItem] = [],
         personalPlaylistsByUser: [String: [MusicSearchItem]] = [:],
         editableIDs: Set<String> = [],
         savedSongTrackIDs: Set<String> = []) {
        self.authorized = authorized
        self.savedIDs = savedIDs
        self.operationSucceeds = operationSucceeds
        self.authorizeThrows = authorizeThrows
        self.accountPlaylistItems = accountPlaylistItems
        self.personalPlaylistsByUser = personalPlaylistsByUser
        self.editableIDs = editableIDs
        self.savedSongTrackIDs = savedSongTrackIDs
    }

    var isAuthorized: Bool { authorized }

    func authorize() async throws {
        authorizeCallCount += 1
        if authorizeThrows {
            throw SpotifyAuthError.notAuthorized
        }
        authorized = true
    }

    func signOut() {
        signOutCallCount += 1
        authorized = false
    }

    func accountPlaylists() async -> [MusicSearchItem] {
        accountPlaylistsCallCount += 1
        if revokesOnFetch {
            authorized = false
        }
        return accountPlaylistItems
    }

    func personalPlaylists(ofUser userID: String) async -> [MusicSearchItem] {
        personalPlaylistsCallCount += 1
        return personalPlaylistsByUser[userID] ?? []
    }

    func editablePlaylistIDs() async -> Set<String> {
        editableIDs
    }

    func isPlaylistSaved(playlistID: String) async -> Bool {
        savedIDs.contains(playlistID)
    }

    func savePlaylist(playlistID: String) async -> Bool {
        saveCallCount += 1
        if operationSucceeds {
            savedIDs.insert(playlistID)
        }
        return operationSucceeds
    }

    func removePlaylist(playlistID: String) async -> Bool {
        removeCallCount += 1
        if operationSucceeds {
            savedIDs.remove(playlistID)
        }
        return operationSucceeds
    }

    func savedSongIDs(trackIDs: [String]) async -> Set<String> {
        savedSongTrackIDs.intersection(trackIDs)
    }

    func saveSong(trackID: String) async -> Bool {
        saveSongCallCount += 1
        if operationSucceeds {
            savedSongTrackIDs.insert(trackID)
        }
        return operationSucceeds
    }

    func removeSong(trackID: String) async -> Bool {
        removeSongCallCount += 1
        if operationSucceeds {
            savedSongTrackIDs.remove(trackID)
        }
        return operationSucceeds
    }

    func addTrack(playlistID: String, trackID: String) async -> Bool {
        if operationSucceeds {
            addedTracks.append((playlistID, trackID))
        }
        return operationSucceeds
    }

    func removeTrack(playlistID: String, trackID: String) async -> Bool {
        if operationSucceeds {
            removedTracks.append((playlistID, trackID))
        }
        return operationSucceeds
    }
}
