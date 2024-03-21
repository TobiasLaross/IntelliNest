//
//  VerticalDivider.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-09.
//

import SwiftUI

struct VerticalDivider: View {
    let color: Color = .gray
    let width: CGFloat = 2
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
            .edgesIgnoringSafeArea(.horizontal)
    }
}
