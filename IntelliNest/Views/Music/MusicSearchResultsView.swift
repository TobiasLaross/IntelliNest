//
//  MusicSearchResultsView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Presents the search results in their own sheet with a tab per media-type
/// category (Låtar / Album / Artister / Spellistor). Shows a spinner while the
/// search runs and a Swedish "no results" state when nothing matched.
struct MusicSearchResultsView: View {
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: MusicMediaType?

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .backgroundModifier()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(viewModel.searchText)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Stäng") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.isSearching {
            ProgressView()
                .tint(.white)
                .padding(.top, 40)
        } else if viewModel.hasNoResults {
            Text("Inga resultat")
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 40)
        } else {
            VStack(spacing: 16) {
                categoryPicker
                resultsList
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    private var categoryPicker: some View {
        Picker("Kategori", selection: selectionBinding) {
            ForEach(viewModel.searchSections) { section in
                Text(section.mediaType.swedishTitle).tag(section.mediaType)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder private var resultsList: some View {
        if let section = currentSection {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(section.items) { item in
                        MusicResultRow(item: item) {
                            Task {
                                await viewModel.play(item: item)
                                dismiss()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// The currently selected category's section, falling back to the first
    /// available category when nothing is selected yet or the previous
    /// selection is no longer present (e.g. after a fresh search).
    private var currentSection: MusicSearchSection? {
        viewModel.searchSections.first { $0.mediaType == resolvedType }
    }

    private var resolvedType: MusicMediaType {
        if let selectedType, viewModel.searchSections.contains(where: { $0.mediaType == selectedType }) {
            return selectedType
        }
        return viewModel.searchSections.first?.mediaType ?? .track
    }

    private var selectionBinding: Binding<MusicMediaType> {
        Binding(get: { resolvedType }, set: { selectedType = $0 })
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
        .foregroundStyle(.white)
        .accessibilityLabel("Spela \(item.name)")
    }
}
