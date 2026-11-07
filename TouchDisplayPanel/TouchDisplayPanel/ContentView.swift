import SwiftUI

/// Landscape, touch-first layout for a second display.
/// Left strip: system controls. Main area: today's calendar.
struct ContentView: View {
    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width >= geo.size.height
            Group {
                if isWide {
                    HStack(spacing: 0) {
                        ControlsStripView()
                            .frame(width: min(320, geo.size.width * 0.30))
                        TodayCalendarView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        ControlsStripView(compact: true)
                            .frame(height: min(200, geo.size.height * 0.32))
                        TodayCalendarView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(PanelTheme.background)
        .ignoresSafeArea()
    }
}

enum PanelTheme {
    static let background = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let strip = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let elevated = Color(red: 0.16, green: 0.18, blue: 0.22)
    static let textPrimary = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let textSecondary = Color(red: 0.65, green: 0.68, blue: 0.72)
    static let accent = Color(red: 0.35, green: 0.72, blue: 0.55)
    static let danger = Color(red: 0.90, green: 0.35, blue: 0.35)
    /// Distinct from system mute/camera — Meet-in-Chrome controls.
    static let meet = Color(red: 0.30, green: 0.62, blue: 0.92)
    static let tapMin: CGFloat = 56
}

#Preview {
    ContentView()
        .environmentObject(AudioControlService())
        .environmentObject(MicMuteService())
        .environmentObject(CameraPrivacyService())
        .environmentObject(MeetControlService())
        .environmentObject(CalendarService())
        .frame(width: 1280, height: 800)
}
