import CoreAudio
import Foundation
import SwiftUI

/// Input mute for the default microphone via Core Audio.
///
/// Notes:
/// - This mutes the **system default input device** (hardware mute property).
/// - Apps that capture audio before the device mute path may still hear you;
///   Zoom/Meet often have their own mute buttons. Prefer this for OS-level cut.
/// - No microphone *recording* permission is required to set device mute.
@MainActor
final class MicMuteService: ObservableObject {
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var statusMessage: String = "Mic: waiting…"

    private var deviceID: AudioDeviceID = kAudioObjectUnknown
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?

    func start() {
        refreshDevice()
        refreshState()
        installListener()
    }

    func toggleMute() {
        setMute(!isMuted)
    }

    func setMute(_ muted: Bool) {
        guard deviceID != kAudioObjectUnknown else {
            statusMessage = "No default input device"
            return
        }
        var value: UInt32 = muted ? 1 : 0
        var address = Self.muteAddress
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &value
        )
        if status == noErr {
            isMuted = muted
            statusMessage = muted ? "Mic muted (system input)" : "Mic live (system input)"
        } else {
            // Some Bluetooth / aggregate devices do not expose input mute.
            statusMessage = "Mic mute unsupported on this device (\(status))"
        }
    }

    private func refreshDevice() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        if status == noErr {
            deviceID = device
            statusMessage = "Mic: ready"
        } else {
            deviceID = kAudioObjectUnknown
            statusMessage = "No default input device"
        }
    }

    private func refreshState() {
        guard deviceID != kAudioObjectUnknown else { return }
        var mute: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = Self.muteAddress
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &mute) == noErr {
            isMuted = mute != 0
        }
    }

    private func installListener() {
        guard deviceID != kAudioObjectUnknown else { return }
        muteListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshState()
            }
        }
        var address = Self.muteAddress
        if let block = muteListenerBlock {
            AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
        }
    }

    private static var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
