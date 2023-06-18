//
//  Lights.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-03.
//

import SwiftUI

struct LightsView: View {
    private let sliderWidth: CGFloat = 60
    private let sliderHeight: CGFloat = 140
    private let bulbTitleSize: CGFloat = 10
    private let roomTitleSize: CGFloat = 14

    @ObservedObject var viewModel: LightsViewModel

    init(viewModel: LightsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                DualBulbRoomView(roomName: viewModel.corridorName,
                                 lightGroup: $viewModel.corridor,
                                 light1: $viewModel.corridorS,
                                 light2: $viewModel.corridorN,
                                 light1Name: viewModel.corridorSouthName,
                                 light2Name: viewModel.corridorNorthName,
                                 reloadLights: viewModel.reload,
                                 onTap: viewModel.onToggle,
                                 onSliderRelease: viewModel.onSliderRelease,
                                 sliderWidth: sliderWidth,
                                 sliderHeight: sliderHeight,
                                 bulbTitleSize: bulbTitleSize,
                                 roomTitleSize: roomTitleSize)
                Spacer()
                DualBulbRoomView(roomName: viewModel.livingroomName,
                                 lightGroup: $viewModel.livingRoom,
                                 light1: $viewModel.sofa,
                                 light2: $viewModel.cozy,
                                 light1Name: viewModel.sofaName,
                                 light2Name: viewModel.cozyName,
                                 reloadLights: viewModel.reload,
                                 onTap: viewModel.onToggle,
                                 onSliderRelease: viewModel.onSliderRelease,
                                 sliderWidth: sliderWidth,
                                 sliderHeight: sliderHeight,
                                 bulbTitleSize: bulbTitleSize,
                                 roomTitleSize: roomTitleSize)
                Spacer()
            }
            .padding(.bottom)

            VStack {
                HStack {
                    SingleRoomLight(roomName: viewModel.guestroomName,
                                    light: $viewModel.guestroom,
                                    reloadLights: viewModel.reload,
                                    onTap: viewModel.onToggle,
                                    onSliderRelease: viewModel.onSliderRelease,
                                    roomTitleSize: roomTitleSize,
                                    sliderWidth: sliderWidth,
                                    sliderHeight: sliderHeight)
                    SingleRoomLight(roomName: viewModel.playroomName,
                                    light: $viewModel.playroom,
                                    reloadLights: viewModel.reload,
                                    onTap: viewModel.onToggle,
                                    onSliderRelease: viewModel.onSliderRelease,
                                    roomTitleSize: roomTitleSize,
                                    sliderWidth: sliderWidth,
                                    sliderHeight: sliderHeight)
                    SingleRoomLight(roomName: viewModel.laundryRoomName,
                                    light: $viewModel.laundryRoom,
                                    reloadLights: viewModel.reload,
                                    onTap: viewModel.onToggle,
                                    onSliderRelease: viewModel.onSliderRelease,
                                    roomTitleSize: roomTitleSize,
                                    sliderWidth: sliderWidth,
                                    sliderHeight: sliderHeight)
                }
            }

            Spacer()
        }
        .padding([.top, .leading])
        .onAppear {
            viewModel.appearedAction(.lights)
        }
    }
}

struct Lights_Previews: PreviewProvider {
    static var previews: some View {
        LightsView(viewModel: LightsViewModel(apiService: HassApiService(urlCreator: URLCreator()), appearedAction: { _ in }))
    }
}
