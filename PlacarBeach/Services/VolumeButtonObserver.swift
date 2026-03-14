import AVFoundation
import Foundation
import MediaPlayer
import SwiftUI
import UIKit

final class VolumeButtonObserver: ObservableObject {
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?

    private let audioSession = AVAudioSession.sharedInstance()
    private var volumeObservation: NSKeyValueObservation?
    private weak var volumeSlider: UISlider?
    private var hiddenVolumeView: MPVolumeView?
    private var lastVolume: Float = 0.5
    private var isAdjustingVolumeInternally = false
    private let neutralVolume: Float = 0.5

    func start() {
        configureAudioSession()
        ensureVolumeView()

        lastVolume = audioSession.outputVolume
        if lastVolume <= 0.05 || lastVolume >= 0.95 {
            setSystemVolume(neutralVolume)
            lastVolume = neutralVolume
        }

        volumeObservation?.invalidate()
        volumeObservation = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let self, let newVolume = change.newValue else { return }
            handleVolumeChange(newVolume)
        }
    }

    func stop() {
        volumeObservation?.invalidate()
        volumeObservation = nil
        onVolumeUp = nil
        onVolumeDown = nil
        volumeSlider = nil
        hiddenVolumeView?.removeFromSuperview()
        hiddenVolumeView = nil
    }

    deinit {
        stop()
    }

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: [])
        } catch {
            print("Volume observer audio session error: \(error.localizedDescription)")
        }
    }

    private func ensureVolumeView() {
        if hiddenVolumeView == nil {
            let volumeView = MPVolumeView(frame: .zero)
            volumeView.alpha = 0.01
            volumeView.isUserInteractionEnabled = false
            hiddenVolumeView = volumeView

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(volumeView)
            }
        }

        if volumeSlider == nil, let volumeView = hiddenVolumeView {
            volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first
        }
    }

    private func handleVolumeChange(_ newVolume: Float) {
        if isAdjustingVolumeInternally {
            isAdjustingVolumeInternally = false
            lastVolume = newVolume
            return
        }

        if newVolume > lastVolume {
            onVolumeUp?()
        } else if newVolume < lastVolume {
            onVolumeDown?()
        }

        lastVolume = newVolume

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.setSystemVolume(self?.neutralVolume ?? 0.5)
        }
    }

    private func setSystemVolume(_ value: Float) {
        guard let slider = volumeSlider else { return }
        isAdjustingVolumeInternally = true
        slider.setValue(value, animated: false)
        slider.sendActions(for: .touchUpInside)
    }
}
