//
//  CamerasView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-03.
//

import SwiftUI

struct CamerasView: View {
    @StateObject var viewModel: CamerasViewModel

    var body: some View {
        VStack {
            ForEach(viewModel.cameraViewModels, id: \.self) { cameraViewModel in
                CameraView(viewModel: cameraViewModel)
            }
        }
    }
}
