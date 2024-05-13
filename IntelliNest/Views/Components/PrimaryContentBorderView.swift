//
//  PrimaryContentBorderView.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-25.
//

import SwiftUI

struct PrimaryContentBorderView: View {
    var isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: dashboardButtonCornerRadius)
            .stroke(isSelected ? Color.primaryContentSelectedBorder : Color.primaryContentBorder,
                    lineWidth: isSelected ? 2 : 3)
    }
}

#Preview {
    PrimaryContentBorderView(isSelected: false)
}
