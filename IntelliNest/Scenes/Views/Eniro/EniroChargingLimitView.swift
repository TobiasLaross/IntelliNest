//
//  EniroChargingLimitView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-19.
//

import SwiftUI

struct EniroChargingLimitView: View {
    @ObservedObject var viewModel: EniroViewModel
    let iconWidth = 35.0
    let iconHeight = 35.0

    var body: some View {
        HStack {}
    }
}

struct EniroChargingLimitView_Previews: PreviewProvider {
    static var previews: some View {
        EniroChargingLimitView(viewModel: .init(websocketService: PreviewProviderUtil.websocketService,
                                                showClimateSchedulingAction: {}))
    }
}
