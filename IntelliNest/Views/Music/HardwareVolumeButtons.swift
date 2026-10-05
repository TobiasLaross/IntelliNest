//
//  HardwareVolumeButtons.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import AVFoundation
import MediaPlayer
import SwiftUI

/// Reads presses of the phone's volume buttons from changes to the phone's own output volume. After each press the
/// phone volume is put back at `restingVolume`, so the buttons never run into the top or bottom and the phone's media
/// volume ends up roughly where it was.
struct VolumeButtonPressDetector {
    private static let tolerance: Float = 0.001
    let restingVolume: Float

    /// Starts from the phone's current volume, moved in from the ends so there is room to press both ways.
    init(startingVolume: Float) {
        restingVolume = min(max(startingVolume, 0.1), 0.9)
    }

    /// True for a press up, false for down, and nil when the volume is back at rest (the echo of our own reset).
    func isRaising(newVolume: Float) -> Bool? {
        guard abs(newVolume - restingVolume) > Self.tolerance else {
            return nil
        }
        return newVolume > restingVolume
    }
}

/// While on screen, turns the volume buttons into speaker volume steps instead of changing the phone's volume.
/// The `MPVolumeView` it hosts keeps the system volume HUD away and is how the phone volume is reset after a press.
struct HardwareVolumeButtons: UIViewRepresentable {
    let onPress: @MainActor (_ raising: Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        // A hidden volume view no longer suppresses the HUD; a near-transparent one does.
        volumeView.alpha = 0.01
        volumeView.isUserInteractionEnabled = false
        context.coordinator.onPress = onPress
        context.coordinator.start(volumeView: volumeView)
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        context.coordinator.onPress = onPress
    }

    static func dismantleUIView(_ uiView: MPVolumeView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var onPress: (@MainActor (Bool) -> Void)?
        private weak var volumeView: MPVolumeView?
        private var detector: VolumeButtonPressDetector?
        private var observation: NSKeyValueObservation?

        func start(volumeView: MPVolumeView) {
            self.volumeView = volumeView
            let session = AVAudioSession.sharedInstance()
            do {
                // Ambient mixes with whatever else plays, so listening for the buttons never pauses other audio.
                try session.setCategory(.ambient)
                try session.setActive(true)
            } catch {
                Log.error("Failed to activate audio session for volume buttons: \(error)")
                return
            }
            let detector = VolumeButtonPressDetector(startingVolume: session.outputVolume)
            self.detector = detector
            setPhoneVolume(detector.restingVolume)
            observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
                guard let volume = change.newValue else {
                    return
                }
                Task { @MainActor in
                    self?.handle(volume)
                }
            }
        }

        func stop() {
            observation?.invalidate()
            observation = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        private func handle(_ volume: Float) {
            guard let detector, let raising = detector.isRaising(newVolume: volume) else {
                return
            }
            onPress?(raising)
            setPhoneVolume(detector.restingVolume)
        }

        private func setPhoneVolume(_ volume: Float) {
            guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else {
                return
            }
            slider.setValue(volume, animated: false)
            slider.sendActions(for: .valueChanged)
        }
    }
}

extension View {
    /// Lets the phone's volume buttons step the speaker volume while this view is on screen.
    func hardwareVolumeButtons(onPress: @escaping @MainActor (_ raising: Bool) -> Void) -> some View {
        background(HardwareVolumeButtons(onPress: onPress).frame(width: 1, height: 1))
    }
}
