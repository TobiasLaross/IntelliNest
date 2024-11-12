//
//  CarHeaterWidget.swift
//  IntelliWidget
//
//  Created by Tobias on 2024-01-12.
//

import SwiftUI
import WidgetKit

struct CarHeaterEntryView: View {
    var entry: SimpleEntry
    let frameSize = 55.0

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Link(destination: URL(string: "IntelliNest://start-car-heater")!) {
                Image(systemName: "car")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(12)
            }
        }
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), isSarahsPillsTaken: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = createEntry()

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let now = Date()
        guard let nextMidnight = calendar.nextDate(after: now,
                                                   matching: DateComponents(hour: 0, minute: 0, second: 0),
                                                   matchingPolicy: .nextTime) else {
            let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(86400)))
            completion(timeline)
            return
        }

        let midnightEntry = SimpleEntry(date: nextMidnight, isSarahsPillsTaken: false)
        let timeline = Timeline(entries: [entry, midnightEntry], policy: .after(nextMidnight))
        completion(timeline)
    }

    private func createEntry() -> SimpleEntry {
        let lastTakenPillsDate = UserDefaults.shared.value(forKey: StorageKeys.sarahPills.rawValue) as? Date
        let isSarahsPillsTaken = Calendar.current.isDateInToday(lastTakenPillsDate ?? .distantPast)
        return SimpleEntry(date: Date(), isSarahsPillsTaken: isSarahsPillsTaken)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let isSarahsPillsTaken: Bool
}

struct CarHeaterWidget: Widget {
    let kind: String = "CarHeaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CarHeaterEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("IntelliWidget")
        .description("Tap the car to activate car heater")
        .supportedFamilies([.accessoryCircular])
    }
}

struct IntelliWidget_Previews: PreviewProvider {
    static var previews: some View {
        CarHeaterEntryView(entry: SimpleEntry(date: Date(), isSarahsPillsTaken: false))
            .containerBackground(.fill.tertiary, for: .widget)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
