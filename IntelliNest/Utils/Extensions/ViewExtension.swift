//
//  ViewExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-24.
//

import SwiftUI

extension View {
    func backgroundModifier() -> some View {
        let gradients = Gradient(stops: [.init(color: .appIconDark.opacity(0.2), location: 0),
                                         .init(color: .appIconBlue.opacity(0.4), location: 0.2),
                                         .init(color: .appIconBlue.opacity(0.5), location: 0.78),
                                         .init(color: .appIconBlue.opacity(0.5), location: 0.9),
                                         .init(color: .appIconGreen.opacity(0.4), location: 1.1)])
        return background(
            LinearGradient(gradient: gradients, startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
    }
}
