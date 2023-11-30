//
//  NordPoolHistoryView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-06.
//

import Charts
import SwiftUI

struct NordPoolHistoryView: View {
    @Binding var isVisible: Bool
    let nordPool: NordPoolEntity

    var body: some View {
        ZStack {
            FullScreenBackgroundOverlay()
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .foregroundColor(.black)
                Chart(nordPool.priceData) {
                    LineMark(
                        x: .value("Timme", $0.hour),
                        y: .value("Öre", $0.price)
                    )
                    .foregroundStyle(by: .value("Day", $0.day.rawValue))
                }
                .chartOverlay { _ in
                    Text(
                        """
                        \(Calendar.currentHour):00
                        \(nordPool.price(hour: Calendar.currentHour)) öre
                        """
                    )
                    .padding(4)
                    .background(.gray.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .position(x: 25, y: 25)
                }
                .chartXAxis {
                    AxisMarks(values: nordPool.hours)
                }
                .chartXAxisLabel(position: .bottom, alignment: .center) {
                    Text("Klockan")
                }
                .chartYAxisLabel(position: .trailing, alignment: .center) {
                    Text("Öre")
                }
                .padding()
            }
            .frame(height: 300)
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            isVisible = false
        }
    }
}

struct NordPoolHistory_Previews: PreviewProvider {
    static var previews: some View {
        NordPoolHistoryView(isVisible: .constant(true),
                            nordPool: .init(entityId: .nordPool))
    }
}
