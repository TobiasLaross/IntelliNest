import SwiftUI

extension Navigator {
    func pop() {
        navigationPath.removeLast()
        updateActiveView()
    }

    func show(destination: Destination) -> some View {
        Group {
            switch destination {
            case .electricity:
                showElectricityView()
            case .home:
                Text("Not implemented show for home")
            case .heaters:
                showHeatersView()
            case .lynk:
                showLynkView()
            case .corridorHeaterDetails:
                showHeaterDetailsView(heaterID: .heaterCorridor)
            case .playroomHeaterDetails:
                showHeaterDetailsView(heaterID: .heaterPlayroom)
            case .eniroClimateSchedule:
                showEniroClimateScheduleView()
            case .roborock:
                showRoborockView()
            case .lights:
                showLightsView()
            }
        }
        .backgroundModifier()
    }

    func push(_ destination: Destination) {
        if currentDestination != destination {
            Task {
                if destination == .home {
                    navigationPath = []
                } else {
                    navigationPath.append(destination)
                }

                await reloadCurrentModel()
            }
            updateActiveView()
        }
    }

    func showElectricityView() -> ElectricityView {
        ElectricityView(viewModel: electricityViewModel)
    }

    func showHomeView() -> HomeView {
        HomeView(viewModel: homeViewModel)
    }

    func showHeatersView() -> HeatersView {
        HeatersView(viewModel: heatersViewModel)
    }

    func showLynkView() -> LynkView {
        LynkView(viewModel: lynkViewModel)
    }

    func showHeaterDetailsView(heaterID: EntityId) -> DetailedHeaterView {
        if heaterID == .heaterCorridor {
            DetailedHeaterView(viewModel: heatersViewModel, selectedHeater: .corridor)
        } else {
            DetailedHeaterView(viewModel: heatersViewModel, selectedHeater: .playroom)
        }
    }

    func showEniroClimateScheduleView() -> EniroClimateScheduleView {
        EniroClimateScheduleView(viewModel: eniroClimateScheduleViewModel)
    }

    func showRoborockView() -> RoborockView {
        RoborockView(viewModel: roborockViewModel)
    }

    func showLightsView() -> LightsView {
        LightsView(viewModel: lightsViewModel)
    }
}
