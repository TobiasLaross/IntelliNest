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
                                 lightGroup: viewModel.corridor,
                                 light1: viewModel.corridorSouth,
                                 light2: viewModel.corridorNorth,
                                 light1Name: viewModel.corridorSouthName,
                                 light2Name: viewModel.corridorNorthName,
                                 onTapAction: viewModel.onToggle,
                                 onSliderChangeAction: viewModel.onSliderChange,
                                 onSliderReleaseAction: viewModel.onSliderRelease,
                                 sliderWidth: sliderWidth,
                                 sliderHeight: sliderHeight,
                                 bulbTitleSize: bulbTitleSize,
                                 roomTitleSize: roomTitleSize)
                Spacer()
                DualBulbRoomView(roomName: viewModel.livingroomName,
                                 lightGroup: viewModel.livingRoom,
                                 light1: viewModel.sofa,
                                 light2: viewModel.cozy,
                                 light1Name: viewModel.sofaName,
                                 light2Name: viewModel.cozyName,
                                 onTapAction: viewModel.onToggle,
                                 onSliderChangeAction: viewModel.onSliderChange,
                                 onSliderReleaseAction: viewModel.onSliderRelease,
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
                                    light: viewModel.guestroom,
                                    onTapAction: viewModel.onToggle,
                                    onSliderChangeAction: viewModel.onSliderChange,
                                    onSliderReleaseAction: viewModel.onSliderRelease,
                                    roomTitleSize: roomTitleSize,
                                    sliderWidth: sliderWidth,
                                    sliderHeight: sliderHeight)
                    SingleRoomLight(roomName: viewModel.playroomName,
                                    light: viewModel.playroom,
                                    onTapAction: viewModel.onToggle,
                                    onSliderChangeAction: viewModel.onSliderChange,
                                    onSliderReleaseAction: viewModel.onSliderRelease,
                                    roomTitleSize: roomTitleSize,
                                    sliderWidth: sliderWidth,
                                    sliderHeight: sliderHeight)
                    SingleRoomLight(roomName: viewModel.laundryRoomName,
                                    light: viewModel.laundryRoom,
                                    onTapAction: viewModel.onToggle,
                                    onSliderChangeAction: viewModel.onSliderChange,
                                    onSliderReleaseAction: viewModel.onSliderRelease,
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
        LightsView(viewModel: .init(websocketService:
            .init(), appearedAction: { _ in }))
    }
}
