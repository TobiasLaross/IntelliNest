//
//  ToolbarItems.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-02.
//

import ShipBookSDK
import SwiftUI

struct ToolBarConnectionStateView: View {
    @ObservedObject var urlCreator: URLCreator

    var body: some View {
        Button {
            Task { @MainActor in
                await urlCreator.updateConnectionState()
            }
        } label: {
            Group {
                switch urlCreator.connectionState {
                case .local:
                    Image(systemName: "wifi")
                case .internet:
                    Image(systemName: "globe")
                case .disconnected:
                    Image(systemName: "wifi.exclamationmark")
                case .loading:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                case .unset:
                    Text("?")
                }
            }
            .foregroundColor(.white)
            .padding(.trailing)
        }
    }
}

struct ToolbarTitleView: View {
    var destination: Destination

    var body: some View {
        Text(destination.title)
            .foregroundColor(.white)
            .font(.headline)
    }
}

struct ToolbarReloadButtonView: View {
    var destination: Destination
    var navigator: Navigator?
    var reloadAction: MainActorAsyncVoidClosure?
    @State var isLoading = false

    var body: some View {
        Button {
            Task { @MainActor in
                isLoading = true
                if let reloadAction {
                    await reloadAction()
                } else if let navigator {
                    await navigator.updateConnectionState()
                    await navigator.reload(for: destination)
                } else {
                    Log.error("Missing reload action in ToolbarReloadButton for \(destination)")
                }
                isLoading = false
            }
        } label: {
            Image(imageName: .refresh)
                .foregroundColor(.white)
                .rotationEffect(.degrees(isLoading ? 360 : 0))
                .animation(isLoading ? .linear(duration: 1) : nil, value: isLoading)
        }
    }
}
