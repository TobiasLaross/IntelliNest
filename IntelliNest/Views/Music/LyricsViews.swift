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
/// near the top; tapping a line re-aligns the timing (the tapped line becomes
/// "now"), correcting drifting LRC timestamps without touching playback. Scrolling
/// just browses — it pauses the auto-follow for a few seconds so the user can read
/// ahead without being yanked back. Plain lyrics show as static scrollable text.
struct LyricsFullView: View {
    let speaker: MediaPlayerEntity
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.dismiss) private var dismiss

    /// The line currently scrolled into focus (the topmost line below the top
    /// margin). Written programmatically to auto-follow playback.
    @State private var focusedLineID: Int?
    @State private var currentIndex: Int?
    /// When the user last scrolled the lyrics by hand. Auto-follow stays paused for
    /// `browseGracePeriod` after this so a scroll to read ahead isn't immediately
    /// snapped back to the playing line. Nil while following.
    @State private var lastManualScroll: Date?

    /// How long auto-follow stays paused after a manual scroll.
    private let browseGracePeriod: TimeInterval = 4
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
                        .contentShape(Rectangle())
                        .onTapGesture { realign(to: index, in: lines) }
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
        // A scroll drag pauses auto-follow so the user can browse; a plain tap moves
        // no distance, so it falls through to a line's tap-to-realign instead.
        .simultaneousGesture(DragGesture().onChanged { _ in lastManualScroll = Date() })
        .onReceive(ticker) { _ in
            advance(lines)
        }
        .onAppear { advance(lines) }
    }

    /// Re-aligns the timeline so the tapped line becomes "now" and resumes
    /// auto-follow from there, snapping it into focus.
    private func realign(to index: Int, in lines: [LyricLine]) {
        viewModel.applyRealign(toLineIndex: index, at: speaker.currentElapsed(asOf: Date()) ?? 0)
        lastManualScroll = nil
        currentIndex = index
        withAnimation(.easeInOut(duration: 0.3)) {
            focusedLineID = index
        }
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

    /// Recomputes the current line from playback time + the manual offset, updating
    /// the highlight. Scrolls it into focus unless the user is browsing — i.e. has
    /// scrolled by hand within the last `browseGracePeriod`.
    private func advance(_ lines: [LyricLine]) {
        let elapsed = (speaker.currentElapsed(asOf: Date()) ?? 0) + viewModel.lyricsOffset
        let index = LyricsTimeline.currentLineIndex(in: lines, at: elapsed)
        guard index != currentIndex else {
            return
        }
        currentIndex = index
        let isBrowsing = lastManualScroll.map { Date().timeIntervalSince($0) < browseGracePeriod } ?? false
        if !isBrowsing, let index {
            withAnimation(.easeInOut(duration: 0.3)) {
                focusedLineID = index
            }
        }
    }
}
