//
//  HeatersAwayModeView.swift
//  IntelliNest
//

import SwiftUI

/// "Bortaläge": holds both heaters at 17° fan 1 while away; Home Assistant restores them 24 h before return.
struct HeatersAwayModeView: View {
    let isOn: Bool
    let returnDate: Date
    let setAwayMode: @MainActor (Bool) -> Void
    let setReturnDate: @MainActor (Date) -> Void

    private static let restoreFormat = Date.FormatStyle(locale: Locale(identifier: "sv_SE"))
        .weekday(.abbreviated).day().month(.abbreviated).hour().minute()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { isOn }, set: { setAwayMode($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    INText("Bortaläge", font: .title2)
                    INText("17℃ och fläkt 1 tills 24 h före hemkomst", foregroundStyle: .white.opacity(0.7), font: .footnote,
                           multilineTextAlignment: .leading)
                }
            }
            .tint(.lightBlue)
            .accessibilityIdentifier("heaters.awayMode.toggle")

            if isOn {
                DatePicker(selection: Binding(get: { returnDate }, set: { setReturnDate($0) }),
                           in: Date()...,
                           displayedComponents: [.date, .hourAndMinute]) {
                    INText("Hemkomst", font: .body)
                }
                .colorScheme(.dark)
                .accessibilityIdentifier("heaters.awayMode.returnPicker")

                INText("Värmen återställs \(HeatersAwayMode.restoreAt(returnDate: returnDate).formatted(Self.restoreFormat))",
                       foregroundStyle: .lightBlue, font: .footnote, multilineTextAlignment: .leading)
            }
        }
        .padding(.horizontal)
    }
}
