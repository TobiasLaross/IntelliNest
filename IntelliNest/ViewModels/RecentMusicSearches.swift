//
//  RecentMusicSearches.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-22.
//

import Foundation

/// The queries listed on the search screen before the user starts typing, newest
/// first. Held apart from `MusicViewModel` because it is purely a device-local
/// convenience and never touches Home Assistant.
@MainActor
final class RecentMusicSearches: ObservableObject {
    static let maximumCount = 10

    @Published private(set) var queries: [String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .shared) {
        self.defaults = defaults
        queries = defaults.stringArray(forKey: StorageKeys.recentMusicSearches.rawValue) ?? []
    }

    /// Moves the query to the top, dropping an earlier copy that differs only in
    /// case so "brynäs" and "Brynäs" don't sit side by side.
    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= MusicViewModel.minimumSearchLength else {
            return
        }
        let remaining = queries.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        save(Array(([trimmed] + remaining).prefix(Self.maximumCount)))
    }

    func remove(_ query: String) {
        save(queries.filter { $0 != query })
    }

    func clear() {
        save([])
    }

    private func save(_ newQueries: [String]) {
        queries = newQueries
        defaults.set(newQueries, forKey: StorageKeys.recentMusicSearches.rawValue)
    }
}
