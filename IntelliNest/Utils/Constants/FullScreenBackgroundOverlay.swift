//
//  FullScreenBackgroundOverlay.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-22.
//

import SwiftUI

struct FullScreenBackgroundOverlay: View {
    var body: some View {
        Rectangle()
            .foregroundStyle(Color.bodyColor)
            .opacity(0.5)
            .edgesIgnoringSafeArea(.bottom)
    }
}

struct FullScreenBackgroundOverlay_Previews: PreviewProvider {
    static var previews: some View {
        FullScreenBackgroundOverlay()
    }
}
