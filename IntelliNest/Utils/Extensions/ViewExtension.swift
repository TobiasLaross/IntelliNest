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
            ZStack {
                Color.black
                LinearGradient(gradient: gradients, startPoint: .top, endPoint: .bottom)
            }
            .edgesIgnoringSafeArea(.all)
        )
    }

    /// Keeps `isVisible` in step with the on-screen keyboard, for chrome that has
    /// to make room for it.
    func tracksKeyboardVisibility(_ isVisible: Binding<Bool>) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isVisible.wrappedValue = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isVisible.wrappedValue = false }
        }
    }
}
