//
//  IntelliNestApp.swift
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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let actionService = QuickActionService.shared
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var navigator = Navigator()

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
                        ActionSheet(title: Text("Välj användare"), buttons: User.allCases.filter({ $0 != .unknownUser }).map { user in
                            .default(Text(user.name)) {
                                UserManager.shared.setUser(user)
                                Task {
                                    await navigator.reloadCurrentModel()
                                }
                            }
                        } + [.cancel()])
                    }
            }
            .onOpenURL { url in
                if url.scheme == "IntelliNest", let path = url.host {
                    if path == "start-car-heater" {
                        navigator.navigationPath = [.eniro]
                        navigator.startKiaHeater()
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
            navigator.startKiaHeater()
        }

        // 3
        actionService.action = nil
    }
}

struct TestApp: App {
    var body: some Scene {
        WindowGroup { Text("Running Unit Tests") }
    }
}
