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
    let startingVolume: Float
    let restingVolume: Float

    /// Starts from the phone's current volume, moved in from the ends so there is room to press both ways.
    init(startingVolume: Float) {
        self.startingVolume = startingVolume
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

/// While on screen and enabled, turns the volume buttons into speaker volume steps instead of changing the phone's volume.
/// The `MPVolumeView` it hosts keeps the system volume HUD away and is how the phone volume is reset after a press.
struct HardwareVolumeButtons: UIViewRepresentable {
    let isEnabled: Bool
    let onPress: @MainActor (_ raising: Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        // A hidden volume view no longer suppresses the HUD; a near-transparent one does.
        volumeView.alpha = 0.01
        volumeView.isUserInteractionEnabled = false
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        context.coordinator.onPress = onPress
        if isEnabled {
            context.coordinator.start(volumeView: uiView)
        } else {
            context.coordinator.stop()
        }
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
        private var foregroundObserver: NSObjectProtocol?

        func start(volumeView: MPVolumeView) {
            guard observation == nil else {
                return
            }
            self.volumeView = volumeView
            let session = AVAudioSession.sharedInstance()
            do {
                // Only a playback session makes the buttons move the media volume this observes; with ambient
                // they change the ringer instead while nothing plays. Mixing keeps it from pausing other audio.
                try session.setCategory(.playback, options: [.mixWithOthers])
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
            // iOS deactivates the session while the app is in the background, and an inactive session hears no presses.
            foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                        object: nil,
                                                                        queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.reactivate()
                }
            }
        }

        func stop() {
            guard let observation else {
                return
            }
            observation.invalidate()
            self.observation = nil
            if let foregroundObserver {
                NotificationCenter.default.removeObserver(foregroundObserver)
            }
            foregroundObserver = nil
            // Hand the phone back at the volume it had, so a muted phone isn't left at the nudged-in resting level.
            if let detector {
                setPhoneVolume(detector.startingVolume)
            }
            detector = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        private func reactivate() {
            guard observation != nil, let detector else {
                return
            }
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                Log.error("Failed to reactivate audio session for volume buttons: \(error)")
                return
            }
            setPhoneVolume(detector.restingVolume)
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
    /// Lets the phone's volume buttons step the speaker volume while this view is on screen and `isEnabled`.
    func hardwareVolumeButtons(isEnabled: Bool, onPress: @escaping @MainActor (_ raising: Bool) -> Void) -> some View {
        background(HardwareVolumeButtons(isEnabled: isEnabled, onPress: onPress).frame(width: 1, height: 1))
    }
}
