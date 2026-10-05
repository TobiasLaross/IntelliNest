//
//  RecentMusicSearches.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-22.
//

import Foundation

/// The items the user picked from search results, newest first, listed on the
/// search screen before anything is typed so one tap plays or opens them again.
/// Held apart from `MusicViewModel` because it is purely a device-local
/// convenience and never touches Home Assistant.
@MainActor
final class RecentMusicSearches: ObservableObject {
    static let maximumCount = 10

    @Published private(set) var items: [MusicSearchItem]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .shared) {
        self.defaults = defaults
        let stored = defaults.data(forKey: StorageKeys.recentMusicPicks.rawValue)
        items = stored.flatMap { try? JSONDecoder().decode([MusicSearchItem].self, from: $0) } ?? []
    }

    /// Moves the item to the top, dropping an earlier copy of it.
    func record(_ item: MusicSearchItem) {
        let remaining = items.filter { $0.uri != item.uri }
        save(Array(([item] + remaining).prefix(Self.maximumCount)))
    }

    func remove(_ item: MusicSearchItem) {
        save(items.filter { $0.uri != item.uri })
    }

    func clear() {
        save([])
    }

    private func save(_ newItems: [MusicSearchItem]) {
        items = newItems
        guard let data = try? JSONEncoder().encode(newItems) else {
            Log.error("Could not encode the recent music picks")
            return
        }
        defaults.set(data, forKey: StorageKeys.recentMusicPicks.rawValue)
    }
}
