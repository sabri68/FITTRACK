import Foundation
import Observation
import SwiftData
import WatchKit

@MainActor
@Observable
final class WatchAppModel {
    let container: ModelContainer
    let workout = WatchWorkoutManager()
    let sync = WatchSyncService()

    var activeSession: WorkoutSession?
    var lastSummary: WatchSummary?
    private(set) var restEnd: Date?
    private(set) var restTotal = 0
    @ObservationIgnored private var restTask: Task<Void, Never>?
    private var didLaunch = false

    init() {
        let inMemory = Persistence.isUITesting
        if let container = try? Persistence.makeContainer(inMemory: inMemory) {
            self.container = container
        } else if let fallback = try? Persistence.makeContainer(inMemory: true) {
            self.container = fallback
        } else {
            fatalError("Stockage indisponible")
        }
    }

    var data: DataService { DataService(container.mainContext) }

    func onLaunch() {
        guard !didLaunch else { return }
        didLaunch = true
        // The watch works on its own: it has the default program until the iPhone sends its version.
        data.seedProgramIfNeeded(sessionsPerWeek: 5)
        sync.start(container: container)
        activeSession = data.unfinishedSession()
    }

    // MARK: Workout

    func start(template: WorkoutTemplate) {
        if let existing = data.unfinishedSession() {
            activeSession = existing
            return
        }
        let session = data.startSession(template: template, device: .watch, phoneSuggestions: sync.phoneSuggestions)
        activeSession = session
        WKInterfaceDevice.current().play(.start)
        if !Persistence.isUITesting {
            Task { await workout.start(at: session.startDate) }
        }
    }

    func togglePause(_ session: WorkoutSession) {
        if session.state == .paused {
            session.resume()
            workout.resume()
        } else {
            session.pause()
            workout.pause()
            stopRest()
        }
        data.save()
        WKInterfaceDevice.current().play(.click)
    }

    func complete(_ set: SetLog, in session: WorkoutSession) {
        if session.state == .paused { togglePause(session) }
        data.completeSet(set)
        WKInterfaceDevice.current().play(.success)
        let remaining = session.orderedExercises.flatMap(\.orderedSets).contains { !$0.isCompleted }
        if remaining, let rest = set.exerciseLog?.restSeconds { startRest(seconds: rest) }
    }

    func finish(_ session: WorkoutSession) async {
        stopRest()
        session.finish()
        session.activeEnergyKcal = workout.activeEnergy
        session.averageHeartRate = workout.averageHeartRate
        data.save()
        session.savedToHealth = await workout.end(at: session.endDate ?? .now)
        data.save()
        sync.send(session)
        let summary = WatchSummary(duration: session.elapsed(), sets: session.completedSets.count,
                                   volume: session.totalVolume, kcal: session.activeEnergyKcal,
                                   savedToHealth: session.savedToHealth)
        WKInterfaceDevice.current().play(.stop)
        activeSession = nil
        // Show the summary once the workout screen has been dismissed.
        try? await Task.sleep(for: .milliseconds(600))
        lastSummary = summary
    }

    func discard(_ session: WorkoutSession) {
        stopRest()
        workout.discard()
        activeSession = nil
        let data = self.data
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            data.discard(session)
        }
    }

    // MARK: Rest timer

    func startRest(seconds: Int) {
        restTotal = seconds
        restEnd = Date().addingTimeInterval(TimeInterval(seconds))
        scheduleRestEnd()
    }

    func addRest(_ seconds: Int) {
        guard let end = restEnd else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(seconds))
        if newEnd <= .now { stopRest(); return }
        restEnd = newEnd
        restTotal = max(1, restTotal + seconds)
        scheduleRestEnd()
    }

    func stopRest() {
        restTask?.cancel()
        restTask = nil
        restEnd = nil
    }

    private func scheduleRestEnd() {
        restTask?.cancel()
        let remaining = max(0, (restEnd ?? .now).timeIntervalSinceNow)
        restTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(.notification)
            self?.restEnd = nil
        }
    }
}

struct WatchSummary: Identifiable {
    let id = UUID()
    var duration: TimeInterval
    var sets: Int
    var volume: Double
    var kcal: Double
    var savedToHealth: Bool
}
