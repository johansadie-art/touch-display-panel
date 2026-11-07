import AppKit
import Foundation
import SwiftUI

/// Webcam / camera privacy toggle placeholder.
///
/// macOS does **not** expose a public API to hard-disable the camera for all
/// processes the way a physical privacy shutter or vendor “camera kill”
/// driver does. v1 therefore:
/// - Tracks a panel-local “privacy on” intent for UI feedback
/// - Opens System Settings → Privacy & Security → Camera so Johan can revoke
///   app access quickly
/// - Documents the hook point for a future Continuity/vendor driver integration
///
/// **Future hook:** replace `togglePrivacy()` body with a call into the user’s
/// webcam driver / USB power switch / Continuity Camera control when available.
@MainActor
final class CameraPrivacyService: ObservableObject {
    @Published private(set) var isPrivacyOn: Bool = false

    /// Shown in the controls footer so the limitation is visible on-device.
    let hardwareNote: String? =
        "Camera toggle opens Privacy settings. Hardware shutter / driver kill switch not wired yet."

    func togglePrivacy() {
        isPrivacyOn.toggle()
        openCameraPrivacySettings()
    }

    func openCameraPrivacySettings() {
        // x-apple.systempreferences URL for Camera privacy pane (macOS Ventura+).
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Camera"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
        if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(fallback)
        }
    }
}
