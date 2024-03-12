//
//  EniroInfoView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-19.
//

import SwiftUI

struct EniroInfoView: View {
    @ObservedObject var viewModel: LynkViewModel

    var body: some View {
        VStack {
            Text("Bilen är **\(viewModel.lynkDoorLock.stateToString())**")
                .foregroundColor(.white)
            Spacer()
                .frame(height: 20)
            HStack {
                /*BatteryView(level: Int(viewModel.batteryLevel.state) ?? 100,
                         isCharging: viewModel.isCharging.isActive, degreeRotation: 90)
                 .padding(.trailing, 30)
                 */
            }
        }
    }
}
