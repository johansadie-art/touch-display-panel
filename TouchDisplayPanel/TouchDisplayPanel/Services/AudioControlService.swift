import AudioToolbox
import CoreAudio
import Foundation
import SwiftUI

/// System output volume and mute via Core Audio (default output device).
@MainActor
final class AudioControlService: ObservableObject {
    @Published private(set) var volume: Float = 0.5
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var statusMessage: String = "Output: waiting…"

    private var deviceID: AudioDeviceID = kAudioObjectUnknown
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?

    func start() {
        refreshDevice()
        refreshState()
        installListeners()
    }

    deinit {
        // Listener teardown is best-effort; avoid MainActor hopping in deinit.
    }

    func setVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        guard deviceID != kAudioObjectUnknown else { return }
        var vol = clamped
        var address = Self.volumeAddress
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &vol
        )
        if status == noErr {
            volume = clamped
            if clamped > 0.001, isMuted {
                setMute(false)
            }
        } else {
            statusMessage = "Volume set failed (\(status))"
        }
    }

    func adjustVolume(by delta: Float) {
        setVolume(volume + delta)
    }

    func toggleMute() {
        setMute(!isMuted)
    }

    func setMute(_ muted: Bool) {
        guard deviceID != kAudioObjectUnknown else { return }
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
        } else {
            statusMessage = "Mute set failed (\(status))"
        }
    }

    private func refreshDevice() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
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
            statusMessage = "Output: \(deviceName(device) ?? "default")"
        } else {
            deviceID = kAudioObjectUnknown
            statusMessage = "No default output device"
        }
    }

    private func refreshState() {
        guard deviceID != kAudioObjectUnknown else { return }

        var vol: Float32 = 0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddress = Self.volumeAddress
        if AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &vol) == noErr {
            volume = vol
        }

        var mute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = Self.muteAddress
        if AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &mute) == noErr {
            isMuted = mute != 0
        }
    }

    private func installListeners() {
        guard deviceID != kAudioObjectUnknown else { return }

        volumeListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshState()
            }
        }
        muteListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshState()
            }
        }

        var volAddress = Self.volumeAddress
        if let block = volumeListenerBlock {
            AudioObjectAddPropertyListenerBlock(deviceID, &volAddress, DispatchQueue.main, block)
        }
        var muteAddress = Self.muteAddress
        if let block = muteListenerBlock {
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, block)
        }
    }

    private func deviceName(_ device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, ptr)
        }
        guard status == noErr else { return nil }
        return name as String
    }

    private static var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
