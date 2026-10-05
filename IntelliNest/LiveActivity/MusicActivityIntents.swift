//
//  MusicActivityIntents.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import AppIntents
import Foundation

enum MusicActivityCommand: String, Sendable {
    case playPause
    case nextTrack
    case previousTrack
    case volumeUp
    case volumeDown
}

/// Hands a Live Activity button press to the app. A `LiveActivityIntent` always runs in the app's process, but this
/// file is also compiled into the widget extension (which only needs the intent type to build the buttons), so the
/// work is reached through a handler the app registers at launch rather than a direct call into app-only code.
enum MusicActivityCommandRouter {
    @MainActor static var handler: (@MainActor (MusicActivityCommand) async -> Void)?

    @MainActor
    static func perform(_ command: MusicActivityCommand) async {
        await handler?(command)
    }
}

struct MusicActivityCommandIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Styr musiken"
    static let isDiscoverable = false

    @Parameter(title: "Kommando")
    var command: String

    init() {}

    init(_ command: MusicActivityCommand) {
        self.command = command.rawValue
    }

    func perform() async throws -> some IntentResult {
        if let command = MusicActivityCommand(rawValue: command) {
            await MusicActivityCommandRouter.perform(command)
        }
        return .result()
    }
}
