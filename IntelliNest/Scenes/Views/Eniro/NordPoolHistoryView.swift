//
//  NordPoolHistoryView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-06.
//

import Charts
import SwiftUI

struct NordPoolHistoryView: View {
    let nordPool: NordPoolEntity
    @State var selectedHour = Calendar.currentHour

    var body: some View {
        GeometryReader { geometry in
            let chartWidth = geometry.size.width * 0.78
            Group {
                Chart(nordPool.priceData) {
                    LineMark(
                        x: .value("", $0.hour),
                        y: .value("", $0.price)
                    )
                    .interpolationMethod(.stepStart)
                    .foregroundStyle(by: .value("Day", $0.day.rawValue))

                    BarMark(x: .value("", max(0, Double(selectedHour) - 0.5)),
                            yStart: .value("", 0),
                            yEnd: .value("", nordPool.price(hour: selectedHour)),
                            width: .fixed(6))
                        .clipShape(Capsule())
                        .foregroundStyle(.gray)
                        .opacity(0.3)
                }
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        updateSelectedHour(at: value.location, width: chartWidth)
                    }
                )
                .sensoryFeedback(.selection, trigger: selectedHour)
                .chartOverlay { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .overlay {
                            Text(
                                """
                                \(selectedHour.description)
                                \(nordPool.price(hour: selectedHour)) öre
                                """
                            )
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        }
                        .foregroundStyle(Color.topBarColor)
                        .frame(width: 75, height: 60)
                        .position(x: 170, y: -40)
                }
                .chartXAxis {
                    AxisMarks(values: nordPool.hours)
                }
                .chartXAxisLabel(position: .bottom, alignment: .center) {
                    Text("Timme")
                }
                .chartYAxisLabel(position: .trailing, alignment: .center) {
                    Text("Öre")
                }
            }
        }
        .background(Color.topBarColor)
        .opacity(0.9)
    }

    private func updateSelectedHour(at location: CGPoint, width: CGFloat) {
        let xPos = location.x
        if xPos <= 0 {
            selectedHour = 0
        } else if xPos >= width {
            selectedHour = 23
        } else {
            selectedHour = Int((23 * xPos / width).rounded())
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
                NordPoolHistoryView(nordPool: nordPool)
                    .frame(height: 350)
                    .padding(.bottom, 16)
                    .padding(.horizontal, 8)
            }
            .backgroundModifier()
        }
    }
}

private extension Int {
    var description: String {
        self <= 9 ? "0\(self):00" : "\(self):00"
    }
}
