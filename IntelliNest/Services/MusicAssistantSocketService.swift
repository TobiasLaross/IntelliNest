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
}

/// Talks to the Music Assistant server's WebSocket API. Each call opens a short
/// connection, sends one command, waits for the reply with the matching
/// `message_id`, and closes — no long-lived socket, since the queue screen polls
/// infrequently. The server pushes a `server_info` frame and event frames that
/// carry no matching id; those are skipped while waiting for the reply.
final class MusicAssistantSocketService: MusicAssistantQueueSocket {
    private let urlString: String
    private let session: URLSession
    private let timeout: TimeInterval

    init(urlString: String = GlobalConstants.musicAssistantWebSocketURLString,
         session: URLSession = .shared,
         timeout: TimeInterval = 5) {
        self.urlString = urlString
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

    // MARK: - WebSocket plumbing

    /// Opens a socket, sends one command, and returns the `result` payload of the
    /// reply with the matching `message_id`. Returns nil on any error, timeout, or
    /// error reply, so callers degrade gracefully.
    private func send(command: String, args: [String: Any]) async -> Data? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        let task = session.webSocketTask(with: url)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        let messageID = "1"
        let payload: [String: Any] = ["command": command, "message_id": messageID, "args": args]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        do {
            return try await withTimeout(timeout) {
                try await task.send(.string(json))
                return try await Self.awaitReply(on: task, messageID: messageID)
            }
        } catch {
            Log.error("Music Assistant socket command \(command) failed: \(error)")
            return nil
        }
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
            guard object["error_code"] == nil, let result = object["result"] else {
                return nil
            }
            return try? JSONSerialization.data(withJSONObject: result)
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
}
