//
//  ToolbarBackButton.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-02.
//

import SwiftUI

struct ToolbarBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .foregroundColor(.white)
        }
    }
}
