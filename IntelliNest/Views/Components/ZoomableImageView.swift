//
//  ZoomableImageView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-09.
//

import SwiftUI
import UIKit

struct ZoomableImageView: View {
    var image: Image
    let isPortrait: Bool
    @Binding var isFullScreen: Bool
    @State var initialScale: CGFloat
    @State private var initialOffset = CGSize.zero
    @State private var accumulatedScale: CGFloat = 1.0
    @State private var latestScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            Group {
                if isPortrait {
                    image
                        .resizable()
                        .scaleEffect(accumulatedScale * latestScale)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(accumulatedScale * latestScale)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .rotationEffect(.degrees(90))
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        latestScale = value.magnitude
                    }
                    .onEnded { _ in
                        accumulatedScale *= latestScale
                        latestScale = 1.0
                    },
                including: .all
            )
            .onTapGesture {
                isFullScreen = false
            }
            .onAppear {
                accumulatedScale = initialScale
            }
        }
    }
}
