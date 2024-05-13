//
//  ErrorBannerView.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-31.
//

import SwiftUI

struct ErrorBannerView: View {
    let title: String
    let message: String

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .frame(height: 60)
            .foregroundStyle(Color.blend(.red, with: .black, ratio: 0.3))
            .background(Color.clear)
            .shadow(radius: 5)
            .padding(.horizontal, 2)
            .overlay {
                VStack {
                    Group {
                        Text(title)
                            .font(.buttonFontLarge)
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                        Text(message)
                            .font(.buttonFontMedium)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.1)
                    }
                    .foregroundColor(.white)
                    .background(Color.clear)
                }
            }
    }
}

#Preview {
    VStack {
        ErrorBannerView(title: "Failed to send bla bla",
                        message: "Status code: 502")
        Spacer()
    }
}
