import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    @State private var model = AppModel.make()
    @State private var errors = ErrorReporter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.health)
                .environment(model.sync)
                .modelContainer(model.container)
                .environment(\.locale, FTFormat.locale)
                .tint(Theme.accent)
                .onAppear { model.onLaunch() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.onBecameActive() }
                }
                .alert(errors.current?.message ?? "", isPresented: Binding(
                    get: { errors.current != nil },
                    set: { if !$0 { errors.current = nil } })
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errors.current?.detail ?? "")
                }
        }
    }
}
