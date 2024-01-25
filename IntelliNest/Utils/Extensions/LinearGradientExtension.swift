//
//  ShapeStyleExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-24.
//

import SwiftUI

extension LinearGradient {
    static var buttonGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [.appIconBlue.opacity(0.5), .appIconGreen.opacity(0.5)]),
                       startPoint: .leading,
                       endPoint: .trailing)
    }
}
