//
//  RestAPIService+Music.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import Foundation

extension RestAPIService {
    /// Calls `music_assistant.search` with `?return_response` and decodes the
    /// grouped result body. Music Assistant search is the only service in the
    /// app that returns a response body, so it gets a dedicated POST path that
    /// reads the JSON back instead of going through `sendPostRequest` (which
    /// discards bodies).
    func searchMusic(query: String, limit: Int = 10) async throws -> MusicSearchResponse {
        let path = "/api/services/\(Domain.musicAssistant.rawValue)/\(Action.search.rawValue)"
        var json = [JSONKey: Any]()
        json[.configEntryID] = GlobalConstants.musicAssistantConfigEntryID
        json[.name] = query
        json[.mediaType] = MusicMediaType.allCases.map(\.rawValue)
        json[.limit] = limit

        let data = try await postExpectingResponseData(path: path, json: json)
        return try decodeSearchResponse(from: data)
    }

    /// Fetches the most recently played playlists from the Music Assistant
    /// library. Music Assistant tracks last-played, so `order_by:
    /// last_played_desc` returns them newest-first across every source (not just
    /// plays started in this app). The favourite filter is left off so a played
    /// non-favourite still shows up.
    func getRecentlyPlayedPlaylists(limit: Int = 5) async throws -> [MusicSearchItem] {
        try await getLibraryPlaylists(favorite: nil, orderBy: "last_played_desc", limit: limit)
    }

    /// Shared `get_library` call for playlists (`?return_response`). `favorite`
    /// applies the favourite filter only when non-nil.
    private func getLibraryPlaylists(favorite: Bool?, orderBy: String, limit: Int) async throws -> [MusicSearchItem] {
        let path = "/api/services/\(Domain.musicAssistant.rawValue)/\(Action.getLibrary.rawValue)"
        var json = [JSONKey: Any]()
        json[.configEntryID] = GlobalConstants.musicAssistantConfigEntryID
        json[.mediaType] = MusicMediaType.playlist.rawValue
        if let favorite {
            json[.favorite] = favorite
        }
        json[.orderBy] = orderBy
        json[.limit] = limit

        let data = try await postExpectingResponseData(path: path, json: json)
        let decoder = JSONDecoder()
        if let wrapper = try? decoder.decode(MusicLibraryServiceResponse.self, from: data) {
            return wrapper.serviceResponse.playlists
        }
        return try decoder.decode(MusicLibraryResponse.self, from: data).playlists
    }

    /// Browses a playlist's tracks via `media_player.browse_media`. The browse
    /// runs against `entityID` (any available speaker), but only reads the
    /// playlist contents — it does not change what that speaker is playing.
    func browsePlaylistTracks(playlistURI: String, on entityID: EntityId) async throws -> [MusicPlaylistTrack] {
        let path = "/api/services/\(Domain.mediaPlayer.rawValue)/\(Action.browseMedia.rawValue)"
        var json = [JSONKey: Any]()
        json[.entityID] = entityID.rawValue
        json[.mediaContentType] = MusicMediaType.playlist.rawValue
        json[.mediaContentID] = playlistURI

        let data = try await postExpectingResponseData(path: path, json: json)
        let decoder = JSONDecoder()
        if let wrapper = try? decoder.decode(MusicPlaylistBrowseServiceResponse.self, from: data) {
            return wrapper.serviceResponse.tracks
        }
        return try decoder.decode(MusicPlaylistBrowseResponse.self, from: data).tracks
    }

    /// POSTs a service call with `?return_response` and returns the response
    /// body, retrying against the external URL when the internal one fails.
    /// Used by the music services that read data back (search, browse).
    private func postExpectingResponseData(path: String, json: [JSONKey: Any]) async throws -> Data {
        let queryParams = ["return_response": "true"]
        let jsonData = createJSONData(json: json)

        guard let request = createURLRequest(path: path, jsonData: jsonData, queryParams: queryParams, method: .post) else {
            throw EntityError.badRequest
        }

        let (statusCode, data) = await sendRequest(request)
        if statusCode == statusCodeOK, let data {
            return data
        }

        let url = request.url?.absoluteString ?? ""
        guard !url.contains(GlobalConstants.baseExternalUrlString) else {
            throw EntityError.httpRequestFailure
        }
        guard let externalRequest = createURLRequest(shouldForceExternalURL: true,
                                                     path: path,
                                                     jsonData: jsonData,
                                                     queryParams: queryParams,
                                                     method: .post) else {
            throw EntityError.badRequest
        }
        let (externalStatusCode, externalData) = await sendRequest(externalRequest)
        guard externalStatusCode == statusCodeOK, let externalData else {
            throw EntityError.httpRequestFailure
        }
        return externalData
    }

    /// The service envelope wraps the actual result under `service_response`.
    /// Decode that wrapper when present, otherwise decode the body directly.
    private func decodeSearchResponse(from data: Data) throws -> MusicSearchResponse {
        let decoder = JSONDecoder()
        if let wrapper = try? decoder.decode(MusicSearchServiceResponse.self, from: data) {
            return wrapper.serviceResponse
        }
        return try decoder.decode(MusicSearchResponse.self, from: data)
    }

    /// Replaces the active speaker's queue and starts playback of `mediaID`
    /// (a `spotify://…` uri). Returns whether the request succeeded so the
    /// caller can surface a failure instead of showing a false playing state.
    @discardableResult
    func playMedia(on entityID: EntityId, mediaID: String, mediaType: MusicMediaType, enqueue: String = "replace") async -> Bool {
        var json = [JSONKey: Any]()
        json[.entityID] = entityID.rawValue
        json[.mediaID] = mediaID
        json[.mediaType] = mediaType.rawValue
        json[.enqueue] = enqueue
        return await sendMusicPostExpectingSuccess(domain: .musicAssistant, action: .playMedia, json: json)
    }

    func mediaTransport(entityID: EntityId, action: Action, reloadTimes: Int = 2) {
        update(entityID: entityID, domain: .mediaPlayer, action: action, reloadTimes: reloadTimes)
    }

    func setVolume(entityID: EntityId, volume: Double, reloadTimes: Int = 1) {
        update(entityID: entityID,
               domain: .mediaPlayer,
               action: .volumeSet,
               dataKey: .volumeLevel,
               dataValue: volume,
               reloadTimes: reloadTimes)
    }

    func setShuffle(entityID: EntityId, shuffle: Bool, reloadTimes: Int = 2) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = entityID.rawValue
            json[.shuffle] = shuffle
            await sendPostRequest(json: json, domain: .mediaPlayer, action: .shuffleSet)
            triggerRepeatReload(times: reloadTimes)
        }
    }

    func setRepeat(entityID: EntityId, repeatMode: MediaRepeatMode, reloadTimes: Int = 2) {
        update(entityID: entityID,
               domain: .mediaPlayer,
               action: .repeatSet,
               dataKey: .repeatMode,
               dataValue: repeatMode.rawValue,
               reloadTimes: reloadTimes)
    }

    /// Adds `memberIDs` into the group led by `leaderID`. When `unjoinFirst` is
    /// set, each member is unjoined from its current group before the join —
    /// Music Assistant accepts a bare `join` on an already-synced player but
    /// silently keeps it in its old group, so re-homing needs the unjoin first.
    /// Returns whether the group change succeeded so the caller can surface a
    /// failure; a failed pre-unjoin aborts before the join is attempted.
    @discardableResult
    func joinSpeakers(leaderID: EntityId, memberIDs: [EntityId], unjoinFirst: Bool = false, reloadTimes: Int = 3) async -> Bool {
        if unjoinFirst {
            for memberID in memberIDs {
                var unjoinJSON = [JSONKey: Any]()
                unjoinJSON[.entityID] = memberID.rawValue
                guard await sendMusicPostExpectingSuccess(domain: .mediaPlayer, action: .unjoin, json: unjoinJSON) else {
                    return false
                }
            }
        }
        var json = [JSONKey: Any]()
        json[.entityID] = leaderID.rawValue
        json[.groupMembers] = memberIDs.map(\.rawValue)
        let success = await sendMusicPostExpectingSuccess(domain: .mediaPlayer, action: .join, json: json)
        triggerRepeatReload(times: reloadTimes)
        return success
    }

    /// Removes `memberID` from whatever group it is currently in. Returns whether
    /// the unjoin succeeded so the caller can surface a failure.
    @discardableResult
    func unjoinSpeaker(memberID: EntityId, reloadTimes: Int = 3) async -> Bool {
        var json = [JSONKey: Any]()
        json[.entityID] = memberID.rawValue
        let success = await sendMusicPostExpectingSuccess(domain: .mediaPlayer, action: .unjoin, json: json)
        triggerRepeatReload(times: reloadTimes)
        return success
    }

    private func sendMusicPostExpectingSuccess(domain: Domain, action: Action, json: [JSONKey: Any]) async -> Bool {
        let path = "/api/services/\(domain.rawValue)/\(action.rawValue)"
        let jsonData = createJSONData(json: json)
        guard let request = createURLRequest(path: path, jsonData: jsonData, method: .post) else {
            return false
        }

        let (statusCode, _) = await sendRequest(request)
        if statusCode == statusCodeOK {
            return true
        }

        let url = request.url?.absoluteString ?? ""
        guard !url.contains(GlobalConstants.baseExternalUrlString),
              let externalRequest = createURLRequest(shouldForceExternalURL: true,
                                                     path: path,
                                                     jsonData: jsonData,
                                                     method: .post) else {
            return false
        }
        let (externalStatusCode, _) = await sendRequest(externalRequest)
        return externalStatusCode == statusCodeOK
    }
}

/// Wrapper for the Home Assistant service-call response envelope.
private struct MusicSearchServiceResponse: Decodable {
    let serviceResponse: MusicSearchResponse

    enum CodingKeys: String, CodingKey {
        case serviceResponse = "service_response"
    }
}

/// Wrapper for the `get_library` service-call response envelope.
private struct MusicLibraryServiceResponse: Decodable {
    let serviceResponse: MusicLibraryResponse

    enum CodingKeys: String, CodingKey {
        case serviceResponse = "service_response"
    }
}

/// Wrapper for the `browse_media` service-call response envelope.
private struct MusicPlaylistBrowseServiceResponse: Decodable {
    let serviceResponse: MusicPlaylistBrowseResponse

    enum CodingKeys: String, CodingKey {
        case serviceResponse = "service_response"
    }
}
