//
//  HomeWidget.swift
//  IntelliWidgetExtension
//
//  Created by Tobias on 2024-01-20.
//

import SwiftUI
import WidgetKit

struct HomeWidgetEntryView: View {
    var entry: SimpleEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Link(destination: URL(string: "IntelliNest://home")!) {
                if UserManager.currentUser == .sarah && !entry.isSarahsPillsTaken {
                    Image(systemName: "pills.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(10)
                } else {
                    // Image("widget-home-icon")
                    Image(systemName: "house")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(12)
                }
            }
        }
    }
}

struct HomeWidget: Widget {
    let kind: String = "HomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HomeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("IntelliWidget")
        .description("Tap the house to navigate to home screen")
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview {
    HomeWidgetEntryView(entry: .init(date: Date(), isSarahsPillsTaken: true))
}
