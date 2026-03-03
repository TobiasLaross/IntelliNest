//
//  HomeWidget.swift
//  IntelliWidgetExtension
//
//  Created by Tobias on 2024-01-20.
//

import SwiftUI
import WidgetKit

struct HomeWidgetEntryView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Link(destination: URL(string: "IntelliNest://home")!) {
                Image(systemName: "house")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(12)
            }
        }
    }
}

struct HomeWidget: Widget {
    let kind: String = "HomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { _ in
            HomeWidgetEntryView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("IntelliWidget")
        .description("Tap the house to navigate to home screen")
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular) {
    HomeWidget()
} timeline: {
    SimpleEntry(date: Date())
    SimpleEntry(date: Date().addingTimeInterval(300))
}
