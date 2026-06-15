//
//  MusicAssistantSocketService.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import Foundation

/// The Music Assistant queue commands Home Assistant exposes no REST service for:
/// reading the full ordered queue and removing an item. Hidden behind a protocol
/// so `MusicViewModel` can be tested with a stub and so the queue degrades
/// cleanly (empty list, failed delete) when the Music Assistant server can't be
/// reached — e.g. when away from the home network.
protocol MusicAssistantQueueSocket: Sendable {
    /// The full ordered queue (current track included), or empty on any failure.
    func queueItems(queueID: String) async -> [MusicQueueItem]
    /// Removes the item from the queue. Returns whether the command succeeded.
    func deleteItem(queueID: String, itemID: String) async -> Bool
    /// Moves the item `positions` slots within the queue: a positive value moves
    /// it later (towards the end), a negative value earlier. Returns whether the
    /// command succeeded.
    func moveItem(queueID: String, itemID: String, positions: Int) async -> Bool
    /// Adds the media item (by uri, e.g. `spotify://playlist/<id>`) to the Music
    /// Assistant library favourites. With MA's Spotify 2-way sync on, this also
    /// follows the playlist on Spotify. Returns whether the command succeeded.
    func addFavorite(uri: String) async -> Bool
    /// Removes a favourite by its Music Assistant library id (parsed from a
    /// `library://<type>/<id>` uri). With 2-way sync on, this also unfollows it on
    /// Spotify. Returns whether the command succeeded.
    func removeFavorite(mediaType: String, libraryItemID: String) async -> Bool
}

/// Talks to the Music Assistant server's WebSocket API. Each call opens a short
/// connection, sends one command, waits for the reply with the matching
/// `message_id`, and closes — no long-lived socket, since the queue screen polls
/// infrequently. The server pushes a `server_info` frame and event frames that
/// carry no matching id; those are skipped while waiting for the reply.
final class MusicAssistantSocketService: MusicAssistantQueueSocket {
    private let urlString: String
    private let token: String
    private let session: URLSession
    private let timeout: TimeInterval

    init(urlString: String = GlobalConstants.musicAssistantWebSocketURLString,
         token: String = GlobalConstants.musicAssistantToken,
         session: URLSession = .shared,
         timeout: TimeInterval = 5) {
        self.urlString = urlString
        self.token = token
        self.session = session
        self.timeout = timeout
    }

    func queueItems(queueID: String) async -> [MusicQueueItem] {
        guard let result = await send(command: "player_queues/items",
                                      args: ["queue_id": queueID, "limit": 500, "offset": 0]) else {
            return []
        }
        guard let items = try? JSONDecoder().decode([MusicQueueItemDTO].self, from: result) else {
            return []
        }
        return items.compactMap(\.queueItem)
    }

    func deleteItem(queueID: String, itemID: String) async -> Bool {
        await send(command: "player_queues/delete_item",
                   args: ["queue_id": queueID, "item_id_or_index": itemID]) != nil
    }

    func moveItem(queueID: String, itemID: String, positions: Int) async -> Bool {
        await send(command: "player_queues/move_item",
                   args: ["queue_id": queueID, "queue_item_id": itemID, "pos_shift": positions]) != nil
    }

    func addFavorite(uri: String) async -> Bool {
        await send(command: "music/favorites/add_item", args: ["item": uri]) != nil
    }

    func removeFavorite(mediaType: String, libraryItemID: String) async -> Bool {
        await send(command: "music/favorites/remove_item",
                   args: ["media_type": mediaType, "library_item_id": libraryItemID]) != nil
    }

    // MARK: - WebSocket plumbing

    /// Opens a socket, authenticates, sends one command, and returns the `result`
    /// payload of the reply with the matching `message_id`. Returns nil on any
    /// error, timeout, or error reply, so callers degrade gracefully.
    private func send(command: String, args: [String: Any]) async -> Data? {
        // Serialize both frames up front so the `@Sendable` timeout closure captures
        // only the resulting JSON strings, never the non-Sendable `args` dictionary.
        guard let url = URL(string: urlString),
              let authJSON = Self.frameJSON(command: "auth", messageID: "auth", args: ["token": token]),
              let commandJSON = Self.frameJSON(command: command, messageID: "1", args: args) else {
            return nil
        }
        let task = session.webSocketTask(with: url)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        do {
            return try await withTimeout(timeout) {
                // MA 2.9+ rejects every command until the connection is authenticated,
                // so send the `auth` frame and await its ack before the real command.
                guard try await Self.authenticate(on: task, authJSON: authJSON) else {
                    Log.error("Music Assistant socket auth failed for command \(command)")
                    return nil
                }
                try await task.send(.string(commandJSON))
                return try await Self.awaitReply(on: task, messageID: "1")
            }
        } catch {
            Log.error("Music Assistant socket command \(command) failed: \(error)")
            return nil
        }
    }

    /// Sends the pre-serialized `auth` frame and returns whether the server acked
    /// with `authenticated: true`.
    private static func authenticate(on task: URLSessionWebSocketTask, authJSON: String) async throws -> Bool {
        try await task.send(.string(authJSON))
        guard let result = try await awaitReply(on: task, messageID: "auth"),
              let object = try? JSONSerialization.jsonObject(with: result) as? [String: Any] else {
            return false
        }
        return object["authenticated"] as? Bool == true
    }

    /// Encodes a `{command, message_id, args}` frame to a JSON string, or nil if it
    /// can't be serialized.
    private static func frameJSON(command: String, messageID: String, args: [String: Any]) -> String? {
        let payload: [String: Any] = ["command": command, "message_id": messageID, "args": args]
        // `JSONSerialization.data(withJSONObject:)` raises an uncatchable Obj-C
        // exception on an invalid object, so validate before serializing.
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Reads frames until one carries the matching `message_id`, returning its
    /// `result` payload (or nil for an error reply). Skips `server_info` and event
    /// frames. Bounded so a chatty server can't loop forever.
    private static func awaitReply(on task: URLSessionWebSocketTask, messageID: String) async throws -> Data? {
        for _ in 0 ..< 50 {
            let message = try await task.receive()
            let frame: Data? = switch message {
            case let .string(text): Data(text.utf8)
            case let .data(data): data
            @unknown default: nil
            }
            guard let frame,
                  let object = try? JSONSerialization.jsonObject(with: frame) as? [String: Any],
                  let replyID = replyMessageID(object), replyID == messageID else {
                continue
            }
            guard object["error_code"] == nil else {
                return nil
            }
            // A successful command may return a non-container `result` — favourites
            // add/remove reply with `null`. `JSONSerialization.data(withJSONObject:)`
            // only accepts a top-level array/dictionary and raises an Obj-C exception
            // (which `try?` can't catch) on a scalar/null, so only serialize a valid
            // container; otherwise signal success with empty Data.
            guard let result = object["result"], JSONSerialization.isValidJSONObject(result) else {
                return Data()
            }
            return (try? JSONSerialization.data(withJSONObject: result)) ?? Data()
        }
        return nil
    }

    /// Reads the reply's `message_id` as a string regardless of whether the
    /// server encodes it as a string or a number — Music Assistant conventionally
    /// echoes an integer id, so matching only `String` would never match.
    private static func replyMessageID(_ object: [String: Any]) -> String? {
        if let stringID = object["message_id"] as? String {
            return stringID
        }
        if let intID = object["message_id"] as? Int {
            return String(intID)
        }
        return nil
    }

    /// Races `operation` against a deadline so a stalled socket can't hang the
    /// queue screen. The losing child is cancelled.
    private func withTimeout<T: Sendable>(_ seconds: TimeInterval,
                                          _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(seconds: seconds)
                throw CancellationError()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw CancellationError()
            }
            return result
        }
    }
}

/// Stand-in used in SwiftUI previews and tests that don't exercise the queue
/// socket. Reports an empty queue and a failed delete, so the Queue screen falls
/// back to its session state without any network access.
struct DisabledMusicAssistantQueueSocket: MusicAssistantQueueSocket {
    func queueItems(queueID _: String) async -> [MusicQueueItem] { [] }
    func deleteItem(queueID _: String, itemID _: String) async -> Bool { false }
    func moveItem(queueID _: String, itemID _: String, positions _: Int) async -> Bool { false }
    func addFavorite(uri _: String) async -> Bool { false }
    func removeFavorite(mediaType _: String, libraryItemID _: String) async -> Bool { false }
}
