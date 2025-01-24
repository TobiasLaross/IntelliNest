//
//  LightsView.swift
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

    private func lightBinding(for entityId: EntityId) -> Binding<LightEntity> {
        Binding<LightEntity>(
            get: { viewModel.lightEntities[entityId] ?? LightEntity(entityId: entityId) },
            set: { viewModel.lightEntities[entityId] = $0 }
        )
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                DualBulbRoomView(roomName: viewModel.corridorName,
                                 lightGroup: lightBinding(for: .lightsInCorridor),
                                 light1: lightBinding(for: .corridorS),
                                 light2: lightBinding(for: .corridorN),
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
                                 lightGroup: lightBinding(for: .lightsInLivingRoom),
                                 light1: lightBinding(for: .sofa),
                                 light2: lightBinding(for: .cozyCorner),
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
                                    light: lightBinding(for: .lightsInGuestRoom),
                                    onTapAction: viewModel.onToggle,
                                    onSliderChangeAction: viewModel.onSliderChange,
                                    onSliderReleaseAction: viewModel.onSliderRelease,
                                    roomTitleSize: roomTitleSize,
                                    sliderWidth: sliderWidth,
                                    sliderHeight: sliderHeight)
                    SingleRoomLight(roomName: viewModel.playroomName,
                                    light: lightBinding(for: .lightsInPlayroom),
                                    onTapAction: viewModel.onToggle,
                                    onSliderChangeAction: viewModel.onSliderChange,
                                    onSliderReleaseAction: viewModel.onSliderRelease,
                                    roomTitleSize: roomTitleSize,
                                    sliderWidth: sliderWidth,
                                    sliderHeight: sliderHeight)
                    SingleRoomLight(roomName: viewModel.laundryRoomName,
                                    light: lightBinding(for: .laundryRoom),
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
    }
}

struct Lights_Previews: PreviewProvider {
    static var previews: some View {
        LightsView(viewModel: .init(restAPIService: PreviewProviderUtil.restAPIService,
                                    repeatReloadAction: { _ in }))
    }
}
