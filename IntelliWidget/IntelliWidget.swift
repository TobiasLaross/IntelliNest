//
//  IntelliWidget.swift
//  IntelliWidget
//
//  Created by Tobias on 2024-01-12.
//

import WidgetKit
import SwiftUI

struct IntelliWidgetEntryView: View {
    var entry: SimpleEntry

    var body: some View {
        HStack {
            Link(destination: URL(string: "IntelliNest://start-car-heater2")!) {
                Image(systemName: "house")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .padding(.horizontal, 8)
            }
            Link(destination: URL(string: "IntelliNest://start-car-heater")!) {
                Image(systemName: "car")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
            }
        }
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate)
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct IntelliWidget: Widget {
    let kind: String = "IntelliWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            IntelliWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("IntelliWidget")
        .description("Tap the car to activate car heater")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct IntelliWidget_Previews: PreviewProvider {
    static var previews: some View {
        IntelliWidgetEntryView(entry: SimpleEntry(date: Date()))
            .containerBackground(.fill.tertiary, for: .widget)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
