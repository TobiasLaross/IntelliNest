//
//  RoborockViews.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-03.
//

import SwiftUI

struct RoborockMapImageView: View {
    var baseURLString: String
    private let urlPath = "local/roborock/map_image_roborock.vacuum.a15.png"
    @State var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { fullView in
            ZStack {
                FullScreenBackgroundOverlay()
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    if let url = URL(string: baseURLString + urlPath) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(max(self.scale, 1.0))
                                    .frame(width: fullView.size.width * self.scale,
                                           height: fullView.size.height * self.scale)
                            } else if phase.error != nil {
                                Image(systemName: "exclamationmark.triangle").padding()
                                // the error here is "cancelled" on any view that wasn't visible at app launch
                            } else {
                                ProgressView().padding()
                            }
                        }
                    }
                }
                .gesture(MagnificationGesture()
                    .onChanged({ (scale) in
                        self.scale = scale
                    }))
            }
        }
    }
}

struct RoborockMapImage_Previews: PreviewProvider {
    static var previews: some View {
        RoborockMapImageView(baseURLString: "")
    }
}
