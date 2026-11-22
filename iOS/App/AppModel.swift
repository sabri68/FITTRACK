import Foundation
import Observation
import SwiftData

enum AppTab: Hashable {
    case dashboard, workout, nutrition, progress, profile
}

/// Application-wide state and services (dependency container).
@MainActor
@Observable
final class AppModel {
    let container: ModelContainer
    let health = HealthKitService()
    let sync = PhoneSyncService()
    let restTimer = RestTimerController()
    @ObservationIgnored let foodClient = OpenFoodFactsClient()

    var selectedTab: AppTab = .dashboard
    /// True while all data is being erased (the UI shows a neutral screen meanwhile).
    var isResetting = false
    /// Workout shown full screen.
    var presentedSession: WorkoutSession?
    /// Set when the persistent store could not be opened (data kept in memory for this launch).
    let startupWarning: String?

    private var didLaunch = false

    init(container: ModelContainer, startupWarning: String? = nil) {
        self.container = container
        self.startupWarning = startupWarning
    }

    var data: DataService { DataService(container.mainContext) }

    /// Factory used by the app entry point. Falls back to an in-memory store instead of crashing.
    static func make() -> AppModel {
        do {
            return AppModel(container: try Persistence.makeContainer(inMemory: Persistence.isUITesting))
        } catch {
            let fallback = try? Persistence.makeContainer(inMemory: true)
            guard let fallback else { fatalError("Impossible de créer le stockage : \(error)") }
            return AppModel(container: fallback,
                            startupWarning: "Vos données n'ont pas pu être ouvertes (\(error.localizedDescription)). Les modifications de cette session ne seront pas conservées.")
        }
    }

    func onLaunch() {
        guard !didLaunch else { return }
        didLaunch = true
        let data = self.data
        data.removeDuplicates()
        let profile = data.ensureProfile()
        if ProcessInfo.processInfo.arguments.contains("-skipOnboarding") && !profile.onboardingCompleted {
            completeOnboarding(profile)
        }
        if profile.onboardingCompleted {
            data.seedProgramIfNeeded(sessionsPerWeek: profile.sessionsPerWeek)
        }
        sync.start(container: container)
        // Offer to resume a workout interrupted by an unexpected termination.
        if let unfinished = data.unfinishedSession(), !Persistence.isUITesting {
            presentedSession = unfinished
        }
        Task { await health.refreshToday() }
    }

    func onBecameActive() {
        health.refreshStatus()
        Task { await health.refreshToday() }
        sync.pushProgram()
    }

    func completeOnboarding(_ profile: UserProfile) {
        let data = self.data
        profile.onboardingCompleted = true
        profile.updatedAt = .now
        data.seedProgramIfNeeded(sessionsPerWeek: profile.sessionsPerWeek)
        if data.weightEntries().isEmpty {
            data.logWeight(profile.weightKg)
        }
        data.save()
        sync.pushProgram()
    }

    /// Erases every record, then recreates a default profile (the onboarding starts again).
    func resetAllData() {
        restTimer.stop()
        presentedSession = nil
        isResetting = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            let data = self.data
            data.deleteAllData()
            data.ensureProfile()
            selectedTab = .dashboard
            isResetting = false
        }
    }

    // MARK: Workout actions

    func startWorkout(template: WorkoutTemplate?) {
        if let existing = data.unfinishedSession() {
            presentedSession = existing
            return
        }
        presentedSession = data.startSession(template: template, device: .iPhone)
    }

    /// Finishes the workout, saves it and writes it to Apple Health when authorised.
    func finishWorkout(_ session: WorkoutSession) async {
        session.finish()
        data.save()
        if health.canWrite, let end = session.endDate {
            let kcal = await health.activeEnergy(from: session.startDate, to: end)
            do {
                try await health.saveWorkout(start: session.startDate, end: end, activeEnergyKcal: kcal)
                session.savedToHealth = true
                if let kcal { session.activeEnergyKcal = kcal }
                if let hr = await health.averageHeartRate(from: session.startDate, to: end) { session.averageHeartRate = hr }
            } catch {
                ErrorReporter.shared.report(error, message: "La séance est enregistrée dans FitTrack mais n'a pas pu être ajoutée à Santé.")
            }
            data.save()
        }
        sync.pushProgram()
    }

    // MARK: Nutrition & weight actions

    func addFood(_ food: FoodItem, grams: Double, meal: MealType, day: Date) {
        let entry = data.addFood(food, grams: grams, meal: meal, day: day)
        guard health.canWrite else { return }
        let macros = entry.macros, name = entry.name, date = entry.date, id = entry.uuid
        Task {
            do {
                try await health.saveFood(name: name, macros: macros, date: date, id: id)
                entry.savedToHealth = true
                data.save()
            } catch {
                // Nutrition stays in FitTrack even if Health refuses the write.
            }
        }
    }

    /// Rewrites the Health samples of an edited entry.
    func resyncFoodWithHealth(_ entry: FoodEntry) {
        guard entry.savedToHealth, health.canWrite else { return }
        let id = entry.uuid, name = entry.name, macros = entry.macros, date = entry.date
        Task {
            await health.deleteFood(id: id)
            try? await health.saveFood(name: name, macros: macros, date: date, id: id)
        }
    }

    func deleteFood(_ entry: FoodEntry) {
        let id = entry.uuid, wasSaved = entry.savedToHealth
        container.mainContext.delete(entry)
        data.save()
        if wasSaved { Task { await health.deleteFood(id: id) } }
    }

    func logWeight(_ kg: Double, date: Date = .now) {
        let entry = data.logWeight(kg, on: date)
        guard health.canWrite else { return }
        Task {
            do {
                try await health.saveBodyMass(kg, date: date)
                entry.savedToHealth = true
                data.save()
            } catch {
                ErrorReporter.shared.report(error, message: "Le poids est enregistré dans FitTrack mais pas dans Santé.")
            }
        }
    }
}
