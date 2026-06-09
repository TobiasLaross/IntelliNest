//
//  MusicView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

struct MusicView: View {
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        VStack(spacing: 16) {
            MusicSearchBar(searchText: $viewModel.searchText,
                           onSubmit: { Task { await viewModel.search() } })

            if let activeSpeaker = viewModel.activeSpeaker {
                NowPlayingView(speaker: activeSpeaker, viewModel: viewModel)
                SpeakerGroupingView(viewModel: viewModel)
            } else {
                SpeakerPickerView(viewModel: viewModel)
            }

            MusicSearchResultsView(viewModel: viewModel)
        }
        .padding(.horizontal)
        .foregroundStyle(.white)
    }
}

private struct MusicSearchBar: View {
    @Binding var searchText: String
    let onSubmit: MainActorVoidClosure

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.7))
            TextField("", text: $searchText, prompt: Text("Sök på Spotify").foregroundColor(.white.opacity(0.6)))
                .foregroundStyle(.white)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .accessibilityLabel("Sök efter musik")
        }
        .padding(10)
        .background(Color.white.opacity(0.12))
        .cornerRadius(12)
    }
}

struct MusicView_Previews: PreviewProvider {
    static var previews: some View {
        MusicView(viewModel: MusicViewModel(restAPIService: PreviewProviderUtil.restAPIService))
            .backgroundModifier()
    }
}
