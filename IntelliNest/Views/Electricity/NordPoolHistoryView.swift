import Charts
import SwiftUI

struct NordPoolHistoryView: View {
    @Binding var nordPool: NordPoolEntity
    @State var selectedQuarter = Calendar.currentQuarter

    var body: some View {
        GeometryReader { geometry in
            let chartWidth = geometry.size.width * 0.78
            Group {
                Chart(nordPool.priceData) {
                    LineMark(
                        x: .value("", $0.quarter),
                        y: .value("", $0.price)
                    )
                    .interpolationMethod(.stepStart)
                    .foregroundStyle(by: .value("Day", $0.day.rawValue))

                    BarMark(x: .value("", max(0, Double(selectedQuarter) - 0.5)),
                            yStart: .value("", 0),
                            yEnd: .value("", nordPool.price(quarter: selectedQuarter)),
                            width: .fixed(6))
                        .clipShape(Capsule())
                        .foregroundStyle(.gray)
                        .opacity(0.3)
                }
                .chartLegend(position: .bottom, alignment: .leading) {
                    HStack(spacing: 12) {
                        LegendItem(label: "Idag", color: .blue)
                        LegendItem(label: "Imorgon", color: .green)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { drag in
                        updateSelectedQuarter(at: drag.location, width: chartWidth)
                    }
                )
                .sensoryFeedback(.selection, trigger: selectedQuarter)
                .chartOverlay(alignment: .top) { _ in
                    HStack {
                        Spacer()
                        VStack(alignment: .leading) {
                            INText(selectedQuarter.asTime, font: .footnote)
                            INText("\(nordPool.price(quarter: selectedQuarter)) öre",
                                   foregroundStyle: .blue.blended(with: .white, amount: 0.4),
                                   font: .footnote,
                                   lineLimit: 1)
                            if nordPool.tomorrowValid {
                                INText("\(nordPool.priceTomorrow(quarter: selectedQuarter)) öre",
                                       foregroundStyle: .green,
                                       font: .footnote,
                                       lineLimit: 1)
                            }
                        }
                    }
                    .padding(.trailing, 48)
                    .offset(y: -60)
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(.white.opacity(0.5))
                        AxisValueLabel()
                            .foregroundStyle(.white)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: nordPool.hourTicks) { value in
                        if let quarter = value.as(Int.self) {
                            let hour = quarter / 4
                            AxisGridLine()
                                .foregroundStyle(.white.opacity(0.8))
                            AxisValueLabel("\(hour)")
                                .foregroundStyle(.white)
                        }
                    }
                }
                .chartXAxisLabel(position: .bottom, alignment: .center) {
                    Text("Timme")
                        .foregroundStyle(.white)
                }
                .chartYAxisLabel(position: .trailing, alignment: .center) {
                    Text("Öre")
                        .foregroundStyle(.white)
                }
            }
        }
        .opacity(0.9)
    }

    private func updateSelectedQuarter(at location: CGPoint, width: CGFloat) {
        let xPos = location.x
        let total = 96.0
        if xPos <= 0 { selectedQuarter = 0; return }
        if xPos >= width { selectedQuarter = 95; return }
        let idx = Int((CGFloat(total - 1) * xPos / width).rounded())
        selectedQuarter = max(0, min(95, idx))
    }
}

private struct LegendItem: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.white)
                .font(.caption)
        }
    }
}

struct NordPoolHistory_Previews: PreviewProvider {
    static var previews: some View {
        var nordPool = NordPoolEntity(entityId: .nordPool)
        nordPool.tomorrowValid = true
        nordPool.today = [32, 26, 18, 17, 19, 30, 433, 57, 76, 61, 54, 52, 49, 47, 52, 59, 69, 69, 66, 61, 45, 46, 42, 28]
        nordPool.tomorrow = [25, 17, 12, 13, 19, 22, 30, 39, 42, 69, 69, 75, 77, 79, 83, 86, 91, 103, 103, 96, 84, 70, 60, 61]

        return ZStack {
            VStack {
                Spacer()
                NordPoolHistoryView(nordPool: .constant(nordPool))
                    .frame(height: 350)
                    .padding(.bottom, 16)
                    .padding(.horizontal, 8)
            }
            .backgroundModifier()
        }
    }
}

extension Int {
    var asTime: String {
        let hour = self / 4
        let minute = (self % 4) * 15
        return String(format: "%02d:%02d", hour, minute)
    }
}
