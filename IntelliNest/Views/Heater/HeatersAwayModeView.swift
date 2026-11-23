//
//  HeatersAwayModeView.swift
//  IntelliNest
//

import SwiftUI

/// "Bortaläge": holds both heaters at 17° fan 1 and turns both purifiers off while away. Home Assistant restores
/// the heaters 24 h before return and the purifiers at the return time.
struct HeatersAwayModeView: View {
    let isOn: Bool
    let returnDate: Date
    let startAwayMode: @MainActor (Date) -> Void
    let endAwayMode: @MainActor () -> Void
    let setReturnDate: @MainActor (Date) -> Void

    @State private var isPickingDate = false
    @State private var pickedDate = HeatersAwayMode.returnDate(daysFromNow: 7, now: Date())

    private static let dateFormat = Date.FormatStyle(locale: Locale(identifier: "sv_SE"))
        .weekday(.abbreviated).day().month(.abbreviated).hour().minute()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isOn {
                activeContent
            } else {
                inactiveContent
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primaryContentBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isOn ? Color.lightBlue.opacity(0.6) : Color.primaryContentBorder))
        .padding(.horizontal)
        .onChange(of: isOn) {
            isPickingDate = false
        }
    }

    private var inactiveContent: some View {
        Group {
            Label("Bortaläge", systemImage: "suitcase.rolling.fill")
                .font(.title3.bold())
            Text("Värmen sänks till 17° och fläkt 1, luftrenarna stängs av. Hemma igen om …")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(HeatersAwayMode.presetDays, id: \.self) { days in
                    chip(HeatersAwayMode.presetTitle(days: days)) {
                        startAwayMode(HeatersAwayMode.returnDate(daysFromNow: days, now: Date()))
                    }
                    .accessibilityIdentifier("heaters.awayMode.preset.\(days)")
                }
            }
            if isPickingDate {
                DatePicker(selection: $pickedDate,
                           in: Date().addingTimeInterval(HeatersAwayMode.restoreLead)...,
                           displayedComponents: [.date, .hourAndMinute]) {
                    Text("Hemkomst")
                }
                .colorScheme(.dark)
                .accessibilityIdentifier("heaters.awayMode.startPicker")
                chip("Starta bortaläge", isPrimary: true) {
                    startAwayMode(pickedDate)
                }
                .accessibilityIdentifier("heaters.awayMode.start")
            } else {
                Button {
                    isPickingDate = true
                } label: {
                    Label("Välj datum", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lightBlue)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("heaters.awayMode.pickDate")
            }
        }
    }

    private var activeContent: some View {
        Group {
            HStack {
                Label("Bortaläge på", systemImage: "suitcase.rolling.fill")
                    .font(.title3.bold())
                Spacer()
                Text("17° · fläkt 1")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.lightBlue.opacity(0.25), in: Capsule())
            }
            Label("Hemkomst \(returnDate.formatted(Self.dateFormat))", systemImage: "house.fill")
            Label {
                Text("Värmen återställs \(HeatersAwayMode.restoreAt(returnDate: returnDate).formatted(Self.dateFormat))")
            } icon: {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
            }
            .foregroundStyle(.white.opacity(0.8))
            Label("Luftrenarna av tills hemkomst", systemImage: "fan")
                .foregroundStyle(.white.opacity(0.8))
            if isPickingDate {
                DatePicker(selection: Binding(get: { returnDate }, set: { setReturnDate($0) }),
                           in: Date()...,
                           displayedComponents: [.date, .hourAndMinute]) {
                    Text("Hemkomst")
                }
                .colorScheme(.dark)
                .accessibilityIdentifier("heaters.awayMode.returnPicker")
            }
            HStack(spacing: 8) {
                chip(isPickingDate ? "Klar" : "Ändra datum") {
                    isPickingDate.toggle()
                }
                .accessibilityIdentifier("heaters.awayMode.changeDate")
                chip("Avsluta nu", isPrimary: true) {
                    endAwayMode()
                }
                .accessibilityIdentifier("heaters.awayMode.end")
            }
        }
    }

    private func chip(_ title: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(isPrimary ? Color.lightBlue : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
