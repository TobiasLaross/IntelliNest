//
//  EniroChargingLimitView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-19.
//

import SwiftUI

struct EniroChargingLimitView: View {
    @ObservedObject var viewModel: LynkViewModel
    let iconWidth = 35.0
    let iconHeight = 35.0

    var body: some View {
        HStack {}
    }
}

struct EniroChargingLimitView_Previews: PreviewProvider {
    static var previews: some View {
        EniroChargingLimitView(viewModel: .init(restAPIService: PreviewProviderUtil.restAPIService,
                                                showClimateSchedulingAction: {}))
    }
}
