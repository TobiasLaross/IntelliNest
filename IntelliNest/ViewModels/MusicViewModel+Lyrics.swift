//
//  MusicViewModel+Lyrics.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-28.
//

import Foundation

/// Lyrics loading and the manual scroll-to-realign correction, split out of
/// `MusicViewModel` to keep that type focused on speaker and playback state.
extension MusicViewModel {
    /// A stable key for the displayed track, used to detect song changes so lyrics
    /// only refetch when needed. Nil when nothing with a title is playing. Reads the
    /// mirrored `displayedActiveSpeaker` so it matches what the card shows.
    var currentLyricsTrackKey: String? {
        guard let speaker = displayedActiveSpeaker,
              let title = speaker.mediaTitle, title.isNotEmpty else {
            return nil
        }
        // Unit separator joins the two fields so a title can't collide with an artist.
        return "\(title)\u{1F}\(speaker.mediaArtist ?? "")"
    }

    /// Toggles the inline lyrics peek, loading lyrics on first expand.
    func toggleLyricsExpanded() {
        isLyricsExpanded.toggle()
        if isLyricsExpanded {
            Task { await refreshLyricsForCurrentTrack() }
        }
    }

    /// Fetches lyrics for the current track when the song has changed since the last
    /// load. Resets the manual realign offset on a change and shows a loading flag so
    /// the UI doesn't flash "not found". Prefetches as soon as the track is known —
    /// not only when the lyrics panel is open — so the lyrics are already in hand by
    /// the time the user taps to show them. No-op when the same track is already
    /// loaded or a fetch for it is in flight.
    func refreshLyricsForCurrentTrack() async {
        guard let key = currentLyricsTrackKey, let speaker = displayedActiveSpeaker else {
            resetLyrics()
            return
        }
        // Skip when this song's lyrics are already applied, or a fetch for it is
        // already in flight. The cached key is latched only on success below, so a
        // failed lookup can still be retried.
        guard key != lyricsTrackKey, key != inFlightLyricsKey else {
            return
        }
        inFlightLyricsKey = key
        isLoadingLyrics = true
        let result = await lyricsService.fetchLyrics(title: speaker.mediaTitle ?? "",
                                                     artist: speaker.mediaArtist ?? "",
                                                     album: speaker.mediaAlbumName,
                                                     durationSeconds: speaker.mediaDuration)
        // The track may have changed while the fetch was in flight; drop a stale
        // result so it can't clobber the new song's lyrics.
        guard currentLyricsTrackKey == key else {
            if inFlightLyricsKey == key {
                inFlightLyricsKey = nil
                isLoadingLyrics = false
            }
            return
        }
        lyrics = result
        lyricsOffset = 0
        isLoadingLyrics = false
        inFlightLyricsKey = nil
        // Latch only on a real hit; `.notFound` collapses transient failures and
        // true misses, so leaving the key unset lets a later trigger retry.
        if result != .notFound {
            lyricsTrackKey = key
        }
    }

    /// Re-aligns synced lyrics so `lineIndex` is the current line at `elapsed`, by
    /// nudging the timing offset. Used by the tap-to-realign gesture; a no-op for
    /// plain or missing lyrics, where there's no timeline to shift.
    func applyRealign(toLineIndex lineIndex: Int, at elapsed: TimeInterval) {
        guard case let .synced(lines) = lyrics else {
            return
        }
        lyricsOffset = LyricsTimeline.offset(toAlign: lineIndex, in: lines, at: elapsed)
    }

    private func resetLyrics() {
        lyrics = .notFound
        lyricsTrackKey = nil
        inFlightLyricsKey = nil
        lyricsOffset = 0
        isLoadingLyrics = false
    }
}
