//
//  IntelliWidget.swift
//  IntelliWidget
//
//  Created by Tobias on 2024-01-12.
//

import SwiftUI
import WidgetKit

struct IntelliWidgetEntryView: View {
    var entry: SimpleEntry

    var body: some View {
        HStack {
            Image(systemName: UserManager.currentUser == .sarah && !entry.isSarahsPillsTaken ? "pills.fill" : "house")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .padding(.horizontal, 8)
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
        IntelliWidgetEntryView(entry: SimpleEntry(date: Date(), isSarahsPillsTaken: false))
            .containerBackground(.fill.tertiary, for: .widget)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
