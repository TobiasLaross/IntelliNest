//
//  MusicActivityCommandSender.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import Foundation

/// Turns a Live Activity button press into Home Assistant calls. Works from the activity's own state alone, since
/// a press can wake the app in the background before any view model has loaded.
@MainActor
struct MusicActivityCommandSender {
    let restAPIService: RestAPIService

    /// The state to show right away, before Home Assistant has confirmed anything.
    static func optimisticState(after command: MusicActivityCommand,
                                from state: MusicActivityAttributes.ContentState,
                                asOf now: Date) -> MusicActivityAttributes.ContentState {
        switch command {
        case .playPause:
            state.togglingPlayback(asOf: now)
        case .volumeUp:
            state.steppingVolume(raising: true)
        case .volumeDown:
            state.steppingVolume(raising: false)
        case .nextTrack, .previousTrack:
            state
        }
    }

    /// Sends `command` for the activity showing `state`, the state as it was before the press.
    func send(_ command: MusicActivityCommand, for state: MusicActivityAttributes.ContentState) async {
        switch command {
        case .playPause:
            await transport(state.isPlaying ? .mediaPause : .mediaPlay, for: state)
        case .nextTrack:
            await transport(.mediaNextTrack, for: state)
        case .previousTrack:
            await transport(.mediaPreviousTrack, for: state)
        case .volumeUp, .volumeDown:
            let volume = Self.optimisticState(after: command, from: state, asOf: Date()).groupVolume
            await withTaskGroup(of: Void.self) { group in
                for speakerID in state.volumeSpeakerIDs {
                    group.addTask {
                        var json = [JSONKey: Any]()
                        json[.entityID] = speakerID
                        json[.volumeLevel] = volume
                        await restAPIService.sendPostRequest(json: json, domain: .mediaPlayer, action: .volumeSet)
                    }
                }
            }
        }
    }

    private func transport(_ action: Action, for state: MusicActivityAttributes.ContentState) async {
        var json = [JSONKey: Any]()
        json[.entityID] = state.transportTargetID
        await restAPIService.sendPostRequest(json: json, domain: .mediaPlayer, action: action)
    }
}
