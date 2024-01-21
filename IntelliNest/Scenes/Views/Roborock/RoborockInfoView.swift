//
//  RoborockInfo.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct RoborockInfoView: View {
    var lastCleanArea: String
    var batteryLevel: Int
    @Binding var showingMapView: Bool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text("Senast städat: \(lastCleanArea.components(separatedBy: ".")[0]) m²")
                    .foregroundColor(.white)
                Text("Batteri-nivå: \(batteryLevel)%")
                    .foregroundColor(.white)
            }
            Button(action: {
                showingMapView = true
            }, label: {
                Image(systemName: "map.circle")
                    .resizable(resizingMode: .stretch)
                    .frame(width: 35,
                           height: 35)
                    .foregroundColor(.white)
            })
            .padding(.leading)
        }
        .background(Color.bodyColor)
    }
}

struct RoborockInfo_Previews: PreviewProvider {
    static var previews: some View {
        RoborockInfoView(
            lastCleanArea: "",
            batteryLevel: 3,
            showingMapView: .constant(false))
    }
}
