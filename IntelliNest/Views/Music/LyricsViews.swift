//
//  LyricsViews.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-28.
//

import SwiftUI

/// One line in the inline peek, identified by its index so SwiftUI can animate the
/// window sliding as the current line advances.
private struct PeekEntry: Identifiable {
    let id: Int
    let text: String
    let isCurrent: Bool
}

/// The compact lyrics peek shown inside the now-playing card when expanded: a few
/// lines that auto-advance with playback, the current line highlighted. Tapping it
/// opens the full-screen lyrics. Falls back to a static head for plain lyrics and a
/// message (or spinner) when none are found.
struct LyricsStripView: View {
    let speaker: MediaPlayerEntity
    @ObservedObject var viewModel: MusicViewModel

    /// How many lines the peek shows at once.
    private let windowSize = 3
    private let stripHeight: CGFloat = 66

    var body: some View {
        Button {
            viewModel.isShowingFullLyrics = true
        } label: {
            content
                .frame(maxWidth: .infinity)
                .frame(height: stripHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öppna sångtext i helskärm")
    }

    @ViewBuilder private var content: some View {
        switch viewModel.lyrics {
        case let .synced(lines):
            syncedPeek(lines)
        case let .plain(text):
            plainPeek(text)
        case .notFound:
            if viewModel.isLoadingLyrics {
                ProgressView().tint(.white)
            } else {
                Text("Ingen sångtext hittades")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func syncedPeek(_ lines: [LyricLine]) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = (speaker.currentElapsed(asOf: context.date) ?? 0) + viewModel.lyricsOffset
            let index = LyricsTimeline.currentLineIndex(in: lines, at: elapsed)
            VStack(spacing: 4) {
                ForEach(peekEntries(lines: lines, current: index)) { entry in
                    Text(entry.text)
                        .font(entry.isCurrent ? .subheadline.weight(.semibold) : .caption)
                        .foregroundStyle(entry.isCurrent ? .yellow : .white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.2), value: index)
        }
    }

    private func plainPeek(_ text: String) -> some View {
        let lines = text
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).isNotEmpty }
            .prefix(windowSize)
        return VStack(spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// A window of up to `windowSize` lines centred on the current one (clamped at the
    /// ends), each marked whether it's the current line. Blank LRC lines render as a
    /// musical note so an instrumental gap isn't an empty row.
    private func peekEntries(lines: [LyricLine], current: Int?) -> [PeekEntry] {
        guard lines.isNotEmpty else {
            return []
        }
        let center = min(max(current ?? 0, 0), lines.count - 1)
        var start = max(center - 1, 0)
        var end = min(start + windowSize - 1, lines.count - 1)
        start = max(end - windowSize + 1, 0)
        end = min(end, lines.count - 1)
        return (start ... end).map { index in
            let text = lines[index].text.isEmpty ? "♪" : lines[index].text
            return PeekEntry(id: index, text: text, isCurrent: current == index)
        }
    }
}

/// The full-screen lyrics view. Synced lyrics auto-scroll to keep the current line
/// near the top; dragging the lyrics re-aligns the timing (the line the user scrolls
/// into focus becomes "now"), correcting drifting LRC timestamps without touching
/// playback. Plain lyrics show as static scrollable text.
struct LyricsFullView: View {
    let speaker: MediaPlayerEntity
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.dismiss) private var dismiss

    /// The line currently scrolled into focus (the topmost line below the top
    /// margin). Written programmatically to auto-follow playback and read back to
    /// re-align when the user scrolls.
    @State private var focusedLineID: Int?
    @State private var currentIndex: Int?
    @State private var isDragging = false

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Sångtext")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Stäng") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
                .backgroundModifier()
                .foregroundStyle(.white)
                .task { await viewModel.refreshLyricsForCurrentTrack() }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.lyrics {
        case let .synced(lines):
            syncedView(lines)
        case let .plain(text):
            plainView(text)
        case .notFound:
            if viewModel.isLoadingLyrics {
                ProgressView().tint(.white)
            } else {
                Text("Ingen sångtext hittades")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func syncedView(_ lines: [LyricLine]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line.text.isEmpty ? "♪" : line.text)
                        .font(.title3)
                        .fontWeight(index == currentIndex ? .bold : .regular)
                        .foregroundStyle(index == currentIndex ? .yellow : .white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(index)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 24)
        }
        // Keep the focused line below the top edge so it reads as the focal line, and
        // leave room to scroll the last lines into focus.
        .contentMargins(.vertical, 140, for: .scrollContent)
        .scrollPosition(id: $focusedLineID)
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in isDragging = true }
                .onEnded { _ in
                    if let focusedLineID {
                        viewModel.applyRealign(toLineIndex: focusedLineID, at: speaker.currentElapsed(asOf: Date()) ?? 0)
                    }
                    isDragging = false
                }
        )
        .onReceive(ticker) { _ in
            advance(lines)
        }
        .onAppear { advance(lines) }
    }

    private func plainView(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
    }

    /// Recomputes the current line from playback time + the manual offset and, unless
    /// the user is actively scrolling, scrolls it into focus.
    private func advance(_ lines: [LyricLine]) {
        let elapsed = (speaker.currentElapsed(asOf: Date()) ?? 0) + viewModel.lyricsOffset
        let index = LyricsTimeline.currentLineIndex(in: lines, at: elapsed)
        guard index != currentIndex else {
            return
        }
        currentIndex = index
        if !isDragging, let index {
            withAnimation(.easeInOut(duration: 0.3)) {
                focusedLineID = index
            }
        }
    }
}
