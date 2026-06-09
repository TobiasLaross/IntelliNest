//
//  SpeakerPickerView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Shown when no speaker is active. Lists the available speakers so the user can
/// pick one to control.
struct SpeakerPickerView: View {
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Välj högtalare")
                .font(.headline)
            ForEach(viewModel.availableSpeakers, id: \.entityId) { speaker in
                Button {
                    viewModel.selectSpeaker(speaker.entityId)
                } label: {
                    HStack {
                        Image(systemName: "hifispeaker.fill")
                        Text(speaker.friendlyName)
                        Spacer()
                        if speaker.isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.green)
                                .accessibilityLabel("Spelar nu")
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
                .accessibilityLabel("Välj \(speaker.friendlyName)")
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
