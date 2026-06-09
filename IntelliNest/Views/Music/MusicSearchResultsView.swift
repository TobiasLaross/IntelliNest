//
//  MusicSearchResultsView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Renders search results grouped by media type, or a Swedish "no results"
/// state when a search returned nothing.
struct MusicSearchResultsView: View {
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        Group {
            if viewModel.isSearching {
                ProgressView()
                    .tint(.white)
                    .padding()
            } else if viewModel.hasNoResults {
                Text("Inga resultat")
                    .foregroundStyle(.white.opacity(0.7))
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.searchSections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.mediaType.swedishTitle)
                                    .font(.headline)
                                ForEach(section.items) { item in
                                    MusicResultRow(item: item) {
                                        Task { await viewModel.play(item: item) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MusicResultRow: View {
    let item: MusicSearchItem
    let onTap: MainActorVoidClosure

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AlbumArtView(urlString: item.imageURL, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                    if let artist = item.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "play.fill")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.vertical, 4)
        }
        .accessibilityLabel("Spela \(item.name)")
    }
}
