import ApplicationServices
import AppKit
import Foundation
import SwiftUI

/// Sends Google Meet-in-Chrome shortcuts (⌘D mute, ⌘E camera) from the touch panel.
/// Prefers focusing a Meet tab first; requires Accessibility (and optionally Automation for Chrome).
@MainActor
final class MeetControlService: ObservableObject {
    @Published private(set) var statusMessage: String = "Meet: ready"
    @Published private(set) var needsAccessibility: Bool = false

    private let chromeBundleIDs = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "com.google.Chrome.dev"
    ]

    private enum Shortcut {
        case mute
        case camera

        var keyCode: CGKeyCode {
            switch self {
            case .mute: return 0x02   // kVK_ANSI_D
            case .camera: return 0x0E // kVK_ANSI_E
            }
        }

        var label: String {
            switch self {
            case .mute: return "Meet mute (⌘D)"
            case .camera: return "Meet camera (⌘E)"
            }
        }
    }

    func toggleMute() {
        send(.mute)
    }

    func toggleCamera() {
        send(.camera)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        needsAccessibility = !trusted
        if trusted {
            if statusMessage.contains("Accessibility") {
                statusMessage = "Meet: ready"
            }
        } else {
            statusMessage = "Meet: allow Accessibility in System Settings, then retry."
        }
    }

    // MARK: - Private

    private enum FocusResult {
        case meetTab
        case chrome
        case none
    }

    private func send(_ shortcut: Shortcut) {
        guard ensureAccessibility(prompt: true) else { return }

        guard runningChrome() != nil else {
            statusMessage = "Meet: open a meet.google.com tab in Chrome, then retry."
            return
        }

        let focus = activateMeetChromeIfPossible()
        let delayNs: UInt64 = focus == .none ? 50_000_000 : 200_000_000

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNs)
            guard ensureAccessibility(prompt: false) else { return }

            let posted = postCommandKey(shortcut.keyCode)
            if posted {
                switch focus {
                case .meetTab:
                    statusMessage = "\(shortcut.label) → Chrome Meet"
                case .chrome:
                    statusMessage = "\(shortcut.label) → Chrome — select the Meet tab if it didn’t apply."
                case .none:
                    statusMessage = "\(shortcut.label) sent — bring Chrome Meet frontmost if it didn’t apply."
                }
            } else {
                statusMessage = "Meet: couldn’t post keystroke. Check Accessibility for Touch Display Panel."
                needsAccessibility = true
            }
        }
    }

    @discardableResult
    private func ensureAccessibility(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        needsAccessibility = !trusted
        if !trusted {
            statusMessage = "Meet: allow Accessibility for Touch Display Panel (System Settings → Privacy & Security → Accessibility), then retry."
        }
        return trusted
    }

    /// Activates Google Chrome and, when Automation allows, selects a meet.google.com tab.
    private func activateMeetChromeIfPossible() -> FocusResult {
        guard let chrome = runningChrome() else { return .none }

        // Prefer AppleScript tab focus; fall back to activating the Chrome process.
        if selectMeetTabViaAppleScript() {
            return .meetTab
        }

        // macOS 14+: cooperative activation (activateIgnoringOtherApps is deprecated).
        NSApp.yieldActivation(to: chrome)
        let activated = chrome.activate()
        if !activated {
            statusMessage = "Meet: couldn’t focus Chrome — leave Meet frontmost and retry."
            return .none
        }
        return .chrome
    }

    private func runningChrome() -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications
        for bundleID in chromeBundleIDs {
            if let match = apps.first(where: { $0.bundleIdentifier == bundleID && !$0.isTerminated }) {
                return match
            }
        }
        return nil
    }

    /// Best-effort: focus a Chrome window/tab whose URL contains meet.google.com.
    /// Requires Automation permission for Google Chrome; failures fall back to process activate.
    private func selectMeetTabViaAppleScript() -> Bool {
        let script = """
        tell application "Google Chrome"
          activate
          set meetFound to false
          repeat with w in windows
            set tabCount to count of tabs of w
            repeat with i from 1 to tabCount
              set tabURL to URL of tab i of w
              if tabURL contains "meet.google.com" then
                set active tab index of w to i
                set index of w to 1
                set meetFound to true
                exit repeat
              end if
            end repeat
            if meetFound then exit repeat
          end repeat
          return meetFound
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        let result = appleScript.executeAndReturnError(&error)
        if error != nil {
            // Automation denied — caller falls back to NSRunningApplication.activate.
            return false
        }
        return result.booleanValue
    }

    private func postCommandKey(_ keyCode: CGKeyCode) -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
