//
//  AlbumArtView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Renders album art from a Music Assistant image URL. MA search items return
/// absolute http(s) URLs, while a speaker's `entity_picture` is relative to the
/// Home Assistant base — this view resolves either form before loading.
struct AlbumArtView: View {
    let urlString: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let url = resolvedURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.1)
            Image(systemName: "music.note")
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var resolvedURL: URL? {
        guard let urlString, urlString.isNotEmpty else {
            return nil
        }
        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }
        let base = GlobalConstants.baseInternalUrlString
        let trimmedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        let path = urlString.hasPrefix("/") ? urlString : "/\(urlString)"
        return URL(string: trimmedBase + path)
    }
}
