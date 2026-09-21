//
//  MusicTrackRows.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-20.
//

import SwiftUI

extension View {
    /// The two queue swipes every track row carries: "Härnäst" puts the song
    /// straight after what's playing, "Sist" appends it to the end. Both sit on the
    /// leading edge, which leaves the trailing edge for the destructive remove a
    /// playlist row needs and means a fast swipe-to-queue can never land on a
    /// delete. A full leading swipe fires "Härnäst" — the one people reach for.
    ///
    /// Only works on a row inside a `List`; `swipeActions` is a no-op elsewhere.
    func queueSwipeActions(viewModel: MusicViewModel,
                           uri: String,
                           title: String,
                           artist: String? = nil,
                           imageURL: String? = nil) -> some View {
        swipeActions(edge: .leading) {
            Button {
                Task {
                    await viewModel.addToQueue(uri: uri, title: title, artist: artist, imageURL: imageURL, placement: .next)
                }
            } label: {
                Label("Härnäst", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            .tint(.green)
            .accessibilityLabel("Spela \(title) härnäst")

            Button {
                Task {
                    await viewModel.addToQueue(uri: uri, title: title, artist: artist, imageURL: imageURL, placement: .last)
                }
            } label: {
                Label("Sist", systemImage: "text.line.last.and.arrowtriangle.forward")
            }
            .tint(.blue)
            .accessibilityLabel("Lägg \(title) sist i kön")
        }
    }

    /// The dark-gradient list styling every music list shares: no system list
    /// chrome, no separators, transparent rows so `backgroundModifier` shows
    /// through. Applied to the `List` itself.
    func musicListStyle() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
    }

    /// The per-row half of `musicListStyle`.
    func musicListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

/// A tappable media row: cover art, name, optional subtitle, and a trailing
/// glyph. Shared by search results, the artist browse, and playlist tracks so
/// every list in the music screen presents an item the same way.
struct MusicMediaRow: View {
    let name: String
    var subtitle: String?
    var imageURL: String?
    var trailingSystemImage = "play.fill"
    let onTap: MainActorVoidClosure

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AlbumArtView(urlString: imageURL, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: trailingSystemImage)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}
