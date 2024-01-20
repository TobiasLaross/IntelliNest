//
//  HomeWidget.swift
//  IntelliWidgetExtension
//
//  Created by Tobias on 2024-01-20.
//

import SwiftUI
import WidgetKit

struct HomeEntryView: View {
    var entry: SimpleEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Link(destination: URL(string: "IntelliNest://home")!) {
                Image(systemName: UserManager.currentUser == .sarah && !entry.isSarahsPillsTaken ? "pills.fill" : "house")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(9)
            }
        }
    }
}

struct HomeWidget: Widget {
    let kind: String = "HomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HomeEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("IntelliWidget")
        .description("Tap the house to navigate to home screen")
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview {
    HomeEntryView(entry: .init(date: Date(), isSarahsPillsTaken: true))
}
