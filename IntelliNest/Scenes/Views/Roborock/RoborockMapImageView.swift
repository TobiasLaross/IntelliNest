//
//  RoborockViews.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-03.
//

import SwiftUI

struct RoborockMapImageView: View {
    @ObservedObject var viewModel: RoborockViewModel

    var body: some View {
        ZStack {
            FullScreenBackgroundOverlay()
                .onTapGesture {
                    viewModel.isShowingMapView = false
                }
            if let url = URL(string: viewModel.imagageURLString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        ZoomableImageView(image: image, isPortrait: true, isFullScreen: .constant(false), initialScale: 1.5)
                            .frame(width: 300, height: 330)
                    } else if phase.error != nil {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .frame(width: 100, height: 100)
                            .padding()
                    } else {
                        ProgressView()
                            .frame(width: 100, height: 100)
                            .padding()
                    }
                }
            }
        }
    }
}
