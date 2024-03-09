//
//  AppMain.swift
//  IntelliNest
//
//  Created by Tobias on 2022-01-26.
//

import SwiftUI

@main
enum AppLauncher {
    static func main() throws {
        if NSClassFromString("XCTestCase") == nil {
            AppMain.main()
        } else {
            TestApp.main()
        }
    }
}

struct AppMain: App {
    @State var shouldShowSelectUserActionSheet = false
    @State private var bannerOffset = -200.0
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var navigator = Navigator()
    private let actionService = QuickActionService.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigator.navigationPath) {
                HomeView(viewModel: navigator.homeViewModel)
                    .backgroundModifier()
                    .navigationDestination(for: Destination.self) { destination in
                        navigator.show(destination: destination)
                            .toolbar {
                                ToolbarItem(placement: .principal) {
                                    ToolbarTitleView(destination: destination)
                                }
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    ToolBarConnectionStateView(urlCreator: navigator.urlCreator)
                                }
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    ToolbarReloadButtonView(destination: destination, reloadAction: navigator.reloadCurrentModel)
                                }
                            }
                            .navigationBarBackButtonHidden(true)
                            .navigationBarItems(leading: ToolbarBackButton())
                    }
                    .navigationBarTitleDisplayMode(.inline)
            }
            .overlay {
                VStack {
                    if let errorBannerTitle = navigator.errorBannerTitle,
                       let errorBannerMessage = navigator.errorBannerMessage {
                        ErrorBannerView(title: errorBannerTitle, message: errorBannerMessage)
                            .offset(y: bannerOffset)
                            .animation(.spring(), value: bannerOffset)
                            .onTapGesture {
                                dismissBanner()
                            }
                            .gesture(
                                DragGesture(minimumDistance: 10)
                                    .onEnded { _ in
                                        dismissBanner()
                                    })
                            .onAppear {
                                withAnimation {
                                    bannerOffset = 0
                                }
                            }
                        Spacer()
                    }
                }
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    navigator.didEnterForeground()
                    performActionIfNeeded()
                } else {
                    navigator.didResignForeground()
                }
            }
            .onAppear {
                Task {
                    await navigator.reloadCurrentModel()
                }
                if UserManager.shared.isUserNotSet {
                    shouldShowSelectUserActionSheet = true
                }
            }
            .actionSheet(isPresented: $shouldShowSelectUserActionSheet) {
                ActionSheet(title: Text("Välj användare"), buttons: User.allCases.filter { $0 != .unknownUser }.map { user in
                    .default(Text(user.name)) {
                        UserManager.shared.setUser(user)
                        Task {
                            await navigator.reloadCurrentModel()
                        }
                    }
                } + [.cancel()])
            }
            .onOpenURL { url in
                if url.scheme == "IntelliNest", let path = url.host {
                    if path == "start-car-heater" {
                        navigator.navigationPath = [.lynk]
                        Task {
                            try? await Task.sleep(seconds: 0.5)
                            navigator.lynkStartClimate()
                        }
                    } else if path == NotificationActionIdentifier.snoozeWashingMachine.rawValue {
                        navigator.navigationPath = []
                        Task {
                            try? await Task.sleep(seconds: 1.0)
                            navigator.snoozeWashingMachine()
                        }
                    } else {
                        navigator.navigationPath = []
                    }
                }
            }
        }
    }

    func performActionIfNeeded() {
        // 1
        guard let action = actionService.action else { return }

        // 2
        switch action {
        case .carheater:
            navigator.lynkStartClimate()
        }

        // 3
        actionService.action = nil
    }

    private func dismissBanner() {
        withAnimation {
            bannerOffset = -200
        }
        Task { @MainActor in
            try? await Task.sleep(seconds: 0.5)
            navigator.errorBannerTitle = nil
            navigator.errorBannerMessage = nil
        }
    }
}

struct TestApp: App {
    var body: some Scene {
        WindowGroup { Text("Running Unit Tests") }
    }
}
