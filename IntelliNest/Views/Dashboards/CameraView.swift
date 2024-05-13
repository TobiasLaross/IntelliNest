//
//  CameraView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-28.
//

// import MobileVLCKit
import SwiftUI

struct VLCPlayerView: UIViewRepresentable {
    let mediaPlayer: VLCMediaPlayerMock // VLCMediaPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        mediaPlayer.drawable = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Nothing to update
    }
}

struct CameraView: View {
    @StateObject var viewModel: CameraViewModel
    @State private var isFullScreen = false
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if let mediaPlayer = viewModel.mediaPlayer, viewModel.isPlaying {
                VStack {
                    VLCPlayerView(mediaPlayer: mediaPlayer)
                    Spacer()
                    Text("Local connection: \(String(viewModel.isLocallyConnected))")
                        .padding(.bottom)
                }
            } else {
                ZStack {
                    if let snapshot = viewModel.snapshot {
                        snapshot
                            .resizable()
                            .onTapGesture {
                                scale = viewModel.snapshotScale
                                isFullScreen = true
                            }
                            .fullScreenCover(isPresented: $isFullScreen) {
                                ZoomableImageView(image: snapshot,
                                                  isPortrait: viewModel.isPortait,
                                                  isFullScreen: $isFullScreen,
                                                  initialScale: viewModel.initialSnapshotScale)
                                    .edgesIgnoringSafeArea(.all)
                            }
                            .transaction { transaction in
                                transaction.disablesAnimations = true
                            }
                            .onDisappear {
                                scale = viewModel.initialSnapshotScale
                            }
                    } else {
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(2, anchor: .center)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(viewModel: .init(urlCreator: .init(), cameraEntityID: .cameraBack, localURL: "", isPortait: true))
    }
}
