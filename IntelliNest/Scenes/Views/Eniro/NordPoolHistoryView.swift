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
    private let chartWidth = 330.0
    @State var selectedHour = Calendar.currentHour

    var body: some View {
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
                DragGesture().onChanged { value in
                    let xPosDragged = value.location.x
                    if xPosDragged <= 0 {
                        selectedHour = 0
                    } else if xPosDragged >= chartWidth {
                        selectedHour = 23
                    } else {
                        selectedHour = Int((23 * xPosDragged / chartWidth).rounded())
                    }
                }
            )
            .chartOverlay { _ in
                RoundedRectangle(cornerRadius: 12)
                    .overlay {
                        Text(
                            """
                            \(selectedHour):00
                            \(nordPool.price(hour: selectedHour)) öre
                            """
                        )
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(0)
                    }
                    .foregroundStyle(Color.topGrayColor)
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
        .background(Color.topGrayColor)
        .opacity(0.9)
    }
}

struct NordPoolHistory_Previews: PreviewProvider {
    static var previews: some View {
        var nordPool = NordPoolEntity(entityId: .nordPool)
        nordPool.tomorrowValid = true
        nordPool.today = [32, 26, 18, 17, 19, 30, 43, 57, 66, 61, 54, 52, 49, 47, 52, 59, 69, 69, 66, 61, 45, 46, 42, 28]
        nordPool.tomorrow = [25, 17, 12, 13, 19, 22, 30, 39, 42, 69, 69, 75, 77, 79, 83, 86, 91, 103, 103, 96, 84, 70, 60, 61]

        return NordPoolHistoryView(nordPool: nordPool)
    }
}
