import SwiftUI

struct ControlsStripView: View {
    var compact: Bool = false

    @EnvironmentObject private var audio: AudioControlService
    @EnvironmentObject private var mic: MicMuteService
    @EnvironmentObject private var camera: CameraPrivacyService

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 16) {
                    volumeBlock
                    toggleButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Controls")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(PanelTheme.textPrimary)

                    volumeBlock
                    toggleButtons
                    Spacer(minLength: 0)
                    statusFooter
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .center : .topLeading)
        .background(PanelTheme.strip)
    }

    private var volumeBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Volume")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(PanelTheme.textSecondary)

            HStack(spacing: 12) {
                TouchButton(
                    systemImage: "speaker.minus.fill",
                    label: "Volume down",
                    isActive: false
                ) {
                    audio.adjustVolume(by: -0.1)
                }

                Slider(
                    value: Binding(
                        get: { Double(audio.volume) },
                        set: { audio.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                .controlSize(.large)
                .tint(PanelTheme.accent)
                .frame(minHeight: PanelTheme.tapMin)

                TouchButton(
                    systemImage: "speaker.plus.fill",
                    label: "Volume up",
                    isActive: false
                ) {
                    audio.adjustVolume(by: 0.1)
                }
            }

            Text("\(Int((audio.volume * 100).rounded()))%")
                .font(.system(size: 18, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(PanelTheme.textPrimary)
        }
    }

    private var toggleButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !compact {
                Text("Audio & camera")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(PanelTheme.textSecondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                TouchToggleButton(
                    systemImage: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    title: audio.isMuted ? "Unmute" : "Mute",
                    isActive: audio.isMuted,
                    activeColor: PanelTheme.danger
                ) {
                    audio.toggleMute()
                }

                TouchToggleButton(
                    systemImage: mic.isMuted ? "mic.slash.fill" : "mic.fill",
                    title: mic.isMuted ? "Mic on" : "Mic mute",
                    isActive: mic.isMuted,
                    activeColor: PanelTheme.danger
                ) {
                    mic.toggleMute()
                }

                TouchToggleButton(
                    systemImage: camera.isPrivacyOn ? "video.slash.fill" : "video.fill",
                    title: camera.isPrivacyOn ? "Cam blocked" : "Camera",
                    isActive: camera.isPrivacyOn,
                    activeColor: PanelTheme.danger
                ) {
                    camera.togglePrivacy()
                }
            }
        }
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(audio.statusMessage)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(PanelTheme.textSecondary)
            if let note = camera.hardwareNote {
                Text(note)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TouchButton: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PanelTheme.textPrimary)
                .frame(width: PanelTheme.tapMin, height: PanelTheme.tapMin)
                .background(isActive ? PanelTheme.danger.opacity(0.35) : PanelTheme.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct TouchToggleButton: View {
    let systemImage: String
    let title: String
    let isActive: Bool
    var activeColor: Color = PanelTheme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(PanelTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 96)
            .padding(.horizontal, 8)
            .background(isActive ? activeColor.opacity(0.35) : PanelTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isActive ? activeColor.opacity(0.8) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
