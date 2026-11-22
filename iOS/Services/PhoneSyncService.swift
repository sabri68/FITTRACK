import Foundation
import Observation
import SwiftData
import WatchConnectivity

/// iPhone side of the iPhone ↔ Apple Watch synchronisation.
///
/// * The program and weight suggestions are pushed with `updateApplicationContext` (latest state wins,
///   delivered as soon as the watch app runs).
/// * Finished watch workouts arrive with `transferUserInfo`, which the system queues while the phone
///   is unreachable and delivers later, so nothing is lost offline. Imports are idempotent (by uuid).
@MainActor
@Observable
final class PhoneSyncService: NSObject {
    private(set) var isSupported = WCSession.isSupported()
    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false
    private(set) var isReachable = false
    private(set) var lastProgramPush: Date?
    private(set) var lastImport: Date?
    private(set) var importedCount = 0

    @ObservationIgnored private var container: ModelContainer?

    func start(container: ModelContainer) {
        self.container = container
        guard isSupported else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    var statusLabel: String {
        if !isSupported { return "Non pris en charge" }
        if !isPaired { return "Aucune Apple Watch jumelée" }
        if !isWatchAppInstalled { return "App non installée sur la montre" }
        return isReachable ? "Connectée" : "Jumelée (hors de portée)"
    }

    /// Sends the current program and progression suggestions to the watch.
    func pushProgram() {
        guard isSupported, let container else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let data = DataService(container.mainContext)
        let templates = data.templates()
        var suggestions: [String: WeightSuggestionDTO] = [:]
        for item in templates.flatMap(\.orderedExercises) where suggestions[item.exerciseId] == nil {
            let s = data.suggestion(for: item)
            suggestions[item.exerciseId] = WeightSuggestionDTO(
                weightKg: s.weightKg, reps: s.reps, basedOn: data.lastSessionSamples(exerciseId: item.exerciseId).date)
        }
        let program = ProgramDTO(templates: templates.map(\.dto), suggestions: suggestions, generatedAt: .now)
        do {
            try session.updateApplicationContext(try SyncMessage.encode(.program, program))
            lastProgramPush = .now
        } catch {
            ErrorReporter.shared.report(error, message: "Impossible d'envoyer le programme à l'Apple Watch.")
        }
    }

    private func handleIncoming(_ dto: SessionDTO) {
        guard let container else { return }
        if DataService(container.mainContext).importSession(dto) {
            importedCount += 1
            lastImport = .now
        }
        pushProgram()
    }

    private func updateState(_ session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
    }
}

extension PhoneSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.updateState(session)
            self.pushProgram()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Required when the user switches to another watch.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.updateState(session)
            self.pushProgram()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.updateState(session) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard SyncMessage.kind(of: userInfo) == .session,
              let dto = try? SyncMessage.decode(SessionDTO.self, from: userInfo) else { return }
        Task { @MainActor in self.handleIncoming(dto) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        switch SyncMessage.kind(of: message) {
        case .requestProgram:
            Task { @MainActor in self.pushProgram() }
        case .session:
            if let dto = try? SyncMessage.decode(SessionDTO.self, from: message) {
                Task { @MainActor in self.handleIncoming(dto) }
            }
        default:
            break
        }
    }
}
