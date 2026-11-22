import SwiftUI
import SwiftData
import WatchKit

@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    /// Called when watchOS relaunches the app during a workout (e.g. after a crash).
    func handleActiveWorkoutRecovery() {
        Task { @MainActor in
            await WatchAppDelegate.model?.workout.recover()
        }
    }

    static weak var model: WatchAppModel?
}

@main
struct FitTrackWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate
    @State private var model = WatchAppModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
                .environment(model.workout)
                .environment(model.sync)
                .modelContainer(model.container)
                .environment(\.locale, FTFormat.locale)
                .tint(WatchTheme.accent)
                .onAppear {
                    WatchAppDelegate.model = model
                    model.onLaunch()
                }
        }
    }
}
