//
//  MusicActivityAttributes.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import ActivityKit
import Foundation

/// The now-playing Live Activity shown on the lock screen and in the Dynamic Island while music plays at home.
/// Compiled into both the app and the widget extension, so it carries plain entity-id strings rather than the
/// app's `EntityId`.
struct MusicActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var artist: String?
        /// The room the activity follows, with a count of the rooms grouped with it ("Köket +2").
        var roomName: String
        var isPlaying: Bool
        /// Playback position in seconds as of `positionDate`. The lock screen extrapolates from this anchor on its
        /// own, so a playing track's progress keeps moving without the app pushing an update every second.
        var position: Double?
        var positionDate: Date?
        var duration: Double?
        /// The average volume of `volumeSpeakerIDs`, 0...1.
        var groupVolume: Double
        /// The album art, cached in the shared app group container: the widget can't load it over the network.
        var artworkFileName: String?
        /// Where play/pause and skip go: the group leader, or the Sonos twin while it plays a native source.
        var transportTargetID: String
        /// Every speaker in the group. A volume step sets them all to one level, like the group slider in the app.
        var volumeSpeakerIDs: [String]
    }
}

extension MusicActivityAttributes.ContentState {
    static let volumeStep = 0.05

    /// When the track would have started had it played uninterrupted: the anchor for the self-updating timers.
    var trackStart: Date? {
        guard let position, let positionDate else {
            return nil
        }
        return positionDate.addingTimeInterval(-position)
    }

    func elapsed(asOf now: Date) -> Double? {
        guard let position else {
            return nil
        }
        var elapsed = position
        if isPlaying, let positionDate {
            elapsed += max(now.timeIntervalSince(positionDate), 0)
        }
        if let duration {
            elapsed = min(elapsed, duration)
        }
        return max(elapsed, 0)
    }

    /// The state after one volume step, kept within 0...1 and rounded so repeated steps don't drift.
    func steppingVolume(raising: Bool) -> Self {
        var stepped = self
        let target = groupVolume + (raising ? Self.volumeStep : -Self.volumeStep)
        stepped.groupVolume = (min(max(target, 0), 1) * 100).rounded() / 100
        return stepped
    }

    /// The state after a play/pause tap. The position is re-anchored at `now`, so a paused bar stops where it is
    /// and a resumed one carries on from there.
    func togglingPlayback(asOf now: Date) -> Self {
        var toggled = self
        toggled.position = elapsed(asOf: now)
        toggled.positionDate = toggled.position == nil ? nil : now
        toggled.isPlaying.toggle()
        return toggled
    }
}

enum MusicActivityArtwork {
    static let appGroupID = "group.se.laross.intellinest.shared"

    static var directoryURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("MusicArtwork", isDirectory: true)
    }

    static func fileURL(named fileName: String) -> URL? {
        directoryURL?.appendingPathComponent(fileName)
    }
}
