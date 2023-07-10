//
//  BulbButton.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-18.
//

import SwiftUI

struct BulbButton: View {
    private let buttonImageSIze: CGFloat = 24

    var light: LightEntity
    let onTapAction: AsyncLightClosure

    var body: some View {
        Button {
            Task { @MainActor in
                await onTapAction(light)
            }
        } label: {
            if light.isActive {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: buttonImageSIze))
                    .foregroundColor(.yellow)
            } else {
                Image(systemName: "lightbulb.slash")
                    .font(.system(size: buttonImageSIze))
            }
        }
        .padding(.vertical, 3.0)
    }
}
