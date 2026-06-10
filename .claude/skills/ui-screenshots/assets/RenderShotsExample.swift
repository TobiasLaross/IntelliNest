// Worked example for the ui-screenshots skill. NOT a committed test — paste this
// method into an existing IntelliNestTests/<Feature>Tests.swift (and add
// `import SwiftUI` / `import UIKit` at the top), run only this method via
// xcodebuild -only-testing, collect the PNGs from /tmp/intellinest-shots/, then
// REVERT (git checkout -- the test file). See SKILL.md.
//
// If the test class body is near the SwiftLint type_body_length limit, put the
// method inside an `extension MusicViewModelTests { ... }` (extensions aren't
// counted toward the class body length).

extension MusicViewModelTests {
    func testRenderMusicScreenshots() {
        let dir = "/tmp/intellinest-shots/music"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // Wrap each rendered view the way the screen-level view does: white text on
        // the app's gradient background, padded, fixed logical width.
        func write(_ view: some View, name: String) {
            let renderer = ImageRenderer(content: view
                .frame(width: 393)
                .foregroundStyle(.white)
                .padding()
                .backgroundModifier())
            renderer.scale = 3
            if let data = renderer.uiImage?.pngData() {
                try? data.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
            }
        }

        // Build sample state directly — entities are `var` structs, so mutate after init.
        func fill(_ viewModel: MusicViewModel) {
            let data: [(EntityId, String, Double)] = [
                (.mediaPlayerKitchen, "Kitchen", 0.4),
                (.mediaPlayerGuestRoom, "Gästrummet", 0.65),
                (.mediaPlayerPlayroom, "Lekrummet", 0.3),
                (.mediaPlayerLivingRoom, "Vardagsrummet", 0.5),
                (.mediaPlayerOutdoorTable, "Matbord ute", 0.18),
                (.mediaPlayerSpa, "Spa", 0.72)
            ]
            for (entityID, name, volume) in data {
                var speaker = MediaPlayerEntity(entityId: entityID, state: "idle", friendlyName: name)
                speaker.volumeLevel = volume
                viewModel.speakers[entityID] = speaker
            }
        }

        // Variation 1 — no active speaker: the picker.
        let pickerVM = MusicViewModel(restAPIService: restAPIService)
        fill(pickerVM)
        write(SpeakerPickerView(viewModel: pickerVM), name: "picker")

        // Variation 2 — an active, playing speaker grouped with another.
        let activeVM = MusicViewModel(restAPIService: restAPIService)
        fill(activeVM)
        var kitchen = activeVM.speakers[.mediaPlayerKitchen]!
        kitchen.state = "playing"
        kitchen.mediaTitle = "Dina färger var blå"
        kitchen.mediaArtist = "Tommy Nilsson"
        kitchen.groupMembers = [.mediaPlayerKitchen, .mediaPlayerGuestRoom]
        activeVM.speakers[.mediaPlayerKitchen] = kitchen
        var guest = activeVM.speakers[.mediaPlayerGuestRoom]!
        guest.groupMembers = [.mediaPlayerKitchen, .mediaPlayerGuestRoom]
        activeVM.speakers[.mediaPlayerGuestRoom] = guest
        activeVM.activeSpeakerID = .mediaPlayerKitchen
        write(VStack(spacing: 16) {
            NowPlayingView(speaker: kitchen, viewModel: activeVM)
            SpeakerGroupingView(viewModel: activeVM)
        }, name: "now-playing-and-grouping")

        print("WROTE SHOTS to \(dir)")
    }
}
