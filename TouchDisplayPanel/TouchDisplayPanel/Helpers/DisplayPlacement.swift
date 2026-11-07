import AppKit
import Foundation

/// Places the primary window full-bleed on a secondary (touch) display when available.
enum DisplayPlacement {
    static func placePrimaryWindowOnTouchDisplay() {
        // Defer until SwiftUI has created the window.
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.isVisible || $0.contentView != nil })
                    ?? NSApp.windows.first else {
                // Retry shortly if the WindowGroup has not materialized yet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    placePrimaryWindowOnTouchDisplay()
                }
                return
            }
            configure(window)
        }
    }

    private static func configure(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior.insert([.fullScreenPrimary, .stationary])
        window.styleMask.insert(.fullSizeContentView)

        let target = preferredTouchScreen() ?? NSScreen.main
        guard let screen = target else { return }

        // Borderless-feeling frame covering the chosen display.
        window.setFrame(screen.visibleFrame, display: true, animate: false)

        // If multiple screens exist and we picked a non-main one, prefer that.
        if let touch = preferredTouchScreen(), touch != NSScreen.main {
            window.setFrameOrigin(touch.visibleFrame.origin)
            window.setFrame(touch.frame, display: true, animate: false)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Heuristic: first non-main screen (the touch panel). Prefer the largest
    /// landscape secondary display when several exist.
    static func preferredTouchScreen() -> NSScreen? {
        let secondaries = NSScreen.screens.filter { $0 != NSScreen.main }
        guard !secondaries.isEmpty else { return nil }

        return secondaries.max { a, b in
            let aLandscape = a.frame.width >= a.frame.height
            let bLandscape = b.frame.width >= b.frame.height
            if aLandscape != bLandscape { return !aLandscape && bLandscape }
            return a.frame.width * a.frame.height < b.frame.width * b.frame.height
        }
    }
}
