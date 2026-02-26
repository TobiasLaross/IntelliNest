import SwiftUI

struct ElectricityView: View {
    @ObservedObject var viewModel: ElectricityViewModel

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    ElectricityFlowView(viewModel: viewModel)
                        .frame(width: 230, height: 230)
                        .padding([.top, .leading], 16)
                    Group {
                        Text("Kostnad idag: ") + Text("\(viewModel.tibberCostToday.state.toKr)").bold() +
                            Text("\nKöpt idag: ") + Text("\(viewModel.pulseConsumptionToday.state.toKWh)").bold()
                    }
                    .font(.buttonFontMedium)
                    .lineLimit(3)
                    .minimumScaleFactor(0.1)
                    .padding(.top, 16)
                    Spacer()
                }
                Spacer()
                NordPoolHistoryView(nordPool: $viewModel.nordPool)
                    .frame(height: 480)
                    .padding(.bottom, 16)
                    .padding(.horizontal, 8)
            }
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    VStack {
        ElectricityView(viewModel: PreviewProviderUtil.electricityViewModel)
            .backgroundModifier()
    }
}
