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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var isPickingDate = false
    @State private var pickedDate = HeatersAwayMode.returnDate(daysFromNow: 7, now: Date())

    private static let dateFormat = Date.FormatStyle(locale: Locale(identifier: "sv_SE"))
        .weekday(.abbreviated).day().month(.abbreviated).hour().minute()
    private static let shortDateFormat = Date.FormatStyle(locale: Locale(identifier: "sv_SE"))
        .weekday(.abbreviated).day().month(.abbreviated)

    var body: some View {
        Group {
            if isExpanded {
                expandedCard
            } else {
                pill
            }
        }
        .padding(.horizontal)
        .animation(reduceMotion ? nil : .snappy, value: isExpanded)
        .onChange(of: isOn) {
            isPickingDate = false
            isExpanded = false
        }
    }

    /// Collapsed: a small centered capsule that stays out of the way, blue with the return date while away.
    private var pill: some View {
        Button {
            isExpanded = true
        } label: {
            Label(isOn ? "Borta till \(returnDate.formatted(Self.shortDateFormat))" : "Bortaläge",
                  systemImage: "suitcase.rolling.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(isOn ? Color.lightBlue.opacity(0.25) : Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(isOn ? Color.lightBlue.opacity(0.6) : Color.primaryContentBorder))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityHint("Visar bortaläget")
        .accessibilityIdentifier("heaters.awayMode.expand")
    }

    /// Expanded: a full-width settings-style row whose header collapses it again.
    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                isExpanded = false
                isPickingDate = false
            } label: {
                HStack(spacing: 10) {
                    Label(isOn ? "Bortaläge på" : "Bortaläge", systemImage: "suitcase.rolling.fill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Döljer bortaläget")
            .accessibilityIdentifier("heaters.awayMode.collapse")
            if isOn {
                activeContent
            } else {
                inactiveContent
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isOn ? Color.lightBlue.opacity(0.6) : Color.primaryContentBorder))
    }

    private var inactiveContent: some View {
        Group {
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
            Text("17° · fläkt 1")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.lightBlue.opacity(0.25), in: Capsule())
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
