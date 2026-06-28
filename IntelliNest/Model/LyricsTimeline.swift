//
//  LyricsTimeline.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-28.
//

import Foundation

/// One timed line of lyrics: the `time` (seconds from the start of the track) at
/// which `text` should become the current line.
struct LyricLine: Equatable {
    let time: TimeInterval
    let text: String
}

/// The outcome of a lyrics lookup. `synced` carries timestamped lines that follow
/// playback; `plain` carries untimed text shown statically (Spotify does the same
/// for tracks with no synced lyrics); `notFound` means neither source had a match.
enum LyricsResult: Equatable {
    case synced([LyricLine])
    case plain(String)
    case notFound
}

/// Pure helpers for parsing LRC lyrics and mapping playback time to a line. Kept
/// free of any clock or networking so the timing logic is deterministic and fully
/// unit-testable.
enum LyricsTimeline {
    /// Matches an LRC timestamp tag like `[00:12.34]`, `[1:02:345]`, or `[00:12]`.
    /// Metadata tags (`[ar:…]`, `[ti:…]`, `[length:…]`) don't match because their
    /// content isn't `digits:digits`, so they're ignored.
    private static let timestampPattern = "\\[(\\d{1,2}):(\\d{2})(?:[.:](\\d{1,3}))?\\]"

    /// Parses raw LRC text into time-sorted lines. A single source line may carry
    /// several timestamps (`[00:10.0][00:20.0]chorus`), which yields one line per
    /// timestamp. Blank/instrumental lines are kept so the gaps between sung lines
    /// are preserved. Returns an empty array when nothing parses (e.g. the input
    /// was actually plain, untimed text).
    static func parseLRC(_ raw: String) -> [LyricLine] {
        guard let regex = try? NSRegularExpression(pattern: timestampPattern) else {
            return []
        }
        var lines: [LyricLine] = []
        for sourceLine in raw.components(separatedBy: .newlines) {
            let range = NSRange(sourceLine.startIndex..., in: sourceLine)
            let matches = regex.matches(in: sourceLine, range: range)
            guard matches.isNotEmpty else {
                continue
            }
            let text = regex.stringByReplacingMatches(in: sourceLine, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespaces)
            for match in matches {
                if let time = seconds(from: match, in: sourceLine) {
                    lines.append(LyricLine(time: time, text: text))
                }
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    /// The index of the line that should be highlighted at `elapsed`: the last line
    /// whose time is at or before `elapsed`. Nil before the first line begins or
    /// when there are no lines.
    static func currentLineIndex(in lines: [LyricLine], at elapsed: TimeInterval) -> Int? {
        var current: Int?
        for (index, line) in lines.enumerated() where line.time <= elapsed {
            current = index
        }
        return current
    }

    /// The timing offset that makes `lineIndex` the current line at `elapsed`, i.e.
    /// `currentLineIndex(at: elapsed + offset)` returns `lineIndex`. Used by the
    /// scroll-to-realign correction: the user scrolls a line to "now" and this is
    /// the nudge applied to every subsequent lookup. Zero for an out-of-range index.
    static func offset(toAlign lineIndex: Int, in lines: [LyricLine], at elapsed: TimeInterval) -> TimeInterval {
        guard lines.indices.contains(lineIndex) else {
            return 0
        }
        return lines[lineIndex].time - elapsed
    }

    private static func seconds(from match: NSTextCheckingResult, in source: String) -> TimeInterval? {
        guard let minutes = intGroup(match, 1, in: source),
              let wholeSeconds = intGroup(match, 2, in: source) else {
            return nil
        }
        var total = TimeInterval(minutes * 60 + wholeSeconds)
        if match.numberOfRanges > 3,
           let fractionRange = Range(match.range(at: 3), in: source) {
            // "34" → 0.34, "340" → 0.340; "0." + digits handles either length.
            total += Double("0." + source[fractionRange]) ?? 0
        }
        return total
    }

    private static func intGroup(_ match: NSTextCheckingResult, _ index: Int, in source: String) -> Int? {
        guard let range = Range(match.range(at: index), in: source) else {
            return nil
        }
        return Int(source[range])
    }
}
