import SwiftUI

@main
struct TouchDisplayPanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.audioControl)
                .environmentObject(appDelegate.micControl)
                .environmentObject(appDelegate.cameraPrivacy)
                .environmentObject(appDelegate.meetControl)
                .environmentObject(appDelegate.calendarService)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let audioControl = AudioControlService()
    let micControl = MicMuteService()
    let cameraPrivacy = CameraPrivacyService()
    let meetControl = MeetControlService()
    let calendarService = CalendarService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DisplayPlacement.placePrimaryWindowOnTouchDisplay()
        audioControl.start()
        micControl.start()
        meetControl.refreshAccessibilityStatus()
        calendarService.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
