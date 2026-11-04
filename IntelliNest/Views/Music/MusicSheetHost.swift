//
//  MusicSheetHost.swift
//  IntelliNest
//
//  Created by Tobias on 2026-11-04.
//

import SwiftUI

/// The layers of the music screen that present sheets of their own. SwiftUI only
/// presents from the topmost view, so each shared sheet is live on one layer at a time.
enum MusicSheetHost {
    /// The music start screen and its search.
    case musicScreen
    /// A browse sheet over the music screen — "Visa alla", an artist or a library
    /// playlist — whose docked mini player opens the player and the rooms over it.
    case browseSheet
    /// The full-screen player.
    case player
}

extension MusicViewModel {
    /// Whether a browse sheet covers the music screen. A playlist opened from the
    /// player sits over the player instead, so it doesn't count.
    var isShowingBrowseSheet: Bool {
        expandedLibrarySection != nil || browsingArtist != nil
            || browsingLibraryPlaylist != nil
    }

    /// Where the full-screen player opens from: over a browse sheet when one is up,
    /// so opening the player never closes the list the user was in.
    private var playerHost: MusicSheetHost {
        isShowingBrowseSheet ? .browseSheet : .musicScreen
    }

    private var topSheetHost: MusicSheetHost {
        isShowingNowPlaying ? .player : playerHost
    }

    /// A sheet binding that is live only while `host` is the topmost layer.
    func presentation(_ keyPath: ReferenceWritableKeyPath<MusicViewModel, Bool>, from host: MusicSheetHost) -> Binding<Bool> {
        Binding(
            get: { self[keyPath: keyPath] && self.topSheetHost == host },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    func nowPlayingPresentation(from host: MusicSheetHost) -> Binding<Bool> {
        Binding(
            get: { self.isShowingNowPlaying && self.playerHost == host },
            set: { self.isShowingNowPlaying = $0 }
        )
    }
}

extension View {
    /// Docks the mini player under a browse sheet while the keyboard is down, and
    /// presents the player and the rooms from the sheet so they open over it.
    func browseSheetMiniPlayer(_ viewModel: MusicViewModel, isEnabled: Bool = true) -> some View {
        modifier(BrowseSheetMiniPlayer(viewModel: viewModel, isEnabled: isEnabled))
    }
}

private struct BrowseSheetMiniPlayer: ViewModifier {
    @ObservedObject var viewModel: MusicViewModel
    let isEnabled: Bool
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if isEnabled, !isKeyboardVisible, viewModel.miniPlayerRooms.isNotEmpty {
                    MiniPlayerView(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
            }
            .tracksKeyboardVisibility($isKeyboardVisible)
            .sheet(isPresented: isEnabled ? viewModel.presentation(\.isShowingSpeakerPicker, from: .browseSheet) : .constant(false)) {
                SpeakerPickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: isEnabled ? viewModel.nowPlayingPresentation(from: .browseSheet) : .constant(false)) {
                NowPlayingSheet(viewModel: viewModel)
            }
    }
}
