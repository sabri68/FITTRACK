import Foundation
import Observation
import SwiftData
import WatchConnectivity

/// Apple Watch side of the synchronisation.
/// Receives the program from the iPhone (application context) and sends finished workouts
/// with `transferUserInfo`, which the system queues until the iPhone is reachable.
@MainActor
@Observable
final class WatchSyncService: NSObject {
    private(set) var isReachable = false
    private(set) var lastProgramDate: Date?
    private(set) var pendingTransfers = 0
    private(set) var phoneSuggestions: [String: WeightSuggestionDTO] = [:]

    @ObservationIgnored private var container: ModelContainer?
    private static let suggestionsKey = "phoneSuggestions"
    private static let programDateKey = "programDate"

    func start(container: ModelContainer) {
        self.container = container
        if let data = UserDefaults.standard.data(forKey: Self.suggestionsKey),
           let decoded = try? JSONDecoder().decode([String: WeightSuggestionDTO].self, from: data) {
            phoneSuggestions = decoded
        }
        lastProgramDate = UserDefaults.standard.object(forKey: Self.programDateKey) as? Date
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var statusLabel: String {
        if pendingTransfers > 0 { return "\(pendingTransfers) séance(s) en attente d'envoi" }
        return isReachable ? "iPhone connecté" : "iPhone hors de portée"
    }

    /// Queues a finished workout for the iPhone (delivered even if the phone is currently unreachable).
    func send(_ session: WorkoutSession) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        do {
            WCSession.default.transferUserInfo(try SyncMessage.encode(.session, session.dto))
            refreshPending()
        } catch {
            ErrorReporter.shared.report(error, message: "Impossible de préparer l'envoi de la séance à l'iPhone.")
        }
    }

    func requestProgram() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated, WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([SyncMessage.kindKey: SyncMessage.Kind.requestProgram.rawValue], replyHandler: nil)
    }

    /// Re-sends finished workouts that were never confirmed as delivered (the iPhone ignores duplicates).
    private func resendUnsynced() {
        guard let container else { return }
        let outstanding = Set(WCSession.default.outstandingUserInfoTransfers.compactMap {
            try? SyncMessage.decode(SessionDTO.self, from: $0.userInfo).uuid
        })
        for session in DataService(container.mainContext).finishedSessions() where !session.syncedToPhone && !outstanding.contains(session.uuid) {
            send(session)
        }
        refreshPending()
    }

    private func refreshPending() {
        pendingTransfers = WCSession.default.outstandingUserInfoTransfers.count
    }

    private func apply(context: [String: Any]) {
        guard let container, SyncMessage.kind(of: context) == .program,
              let program = try? SyncMessage.decode(ProgramDTO.self, from: context) else { return }
        DataService(container.mainContext).applyProgram(program)
        phoneSuggestions = program.suggestions
        lastProgramDate = program.generatedAt
        if let data = try? JSONEncoder().encode(program.suggestions) {
            UserDefaults.standard.set(data, forKey: Self.suggestionsKey)
        }
        UserDefaults.standard.set(program.generatedAt, forKey: Self.programDateKey)
    }

    private func markSynced(_ id: UUID) {
        guard let container else { return }
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.uuid == id })
        if let session = try? container.mainContext.fetch(descriptor).first {
            session.syncedToPhone = true
            DataService(container.mainContext).save()
        }
        refreshPending()
    }
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if !context.isEmpty { self.apply(context: context) }
            self.resendUnsynced()
            self.requestProgram()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if reachable { self.resendUnsynced() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(context: applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        guard error == nil, let dto = try? SyncMessage.decode(SessionDTO.self, from: userInfoTransfer.userInfo) else {
            Task { @MainActor in self.refreshPending() }
            return
        }
        let id = dto.uuid
        Task { @MainActor in self.markSynced(id) }
    }
}
