import Foundation
import HealthKit
import Observation

/// Runs an HKWorkoutSession on the Apple Watch: live heart rate, active energy,
/// background execution during the workout, and saving the workout to Apple Health.
@MainActor
@Observable
final class WatchWorkoutManager: NSObject {
    enum HealthState: Equatable {
        case unavailable, notDetermined, authorized, denied
        var label: String {
            switch self {
            case .unavailable: return "Santé indisponible"
            case .notDetermined: return "Santé non connecté"
            case .authorized: return "Santé connecté"
            case .denied: return "Accès Santé refusé"
            }
        }
    }

    private(set) var heartRate: Double = 0
    private(set) var activeEnergy: Double = 0
    private(set) var isCollecting = false
    private(set) var healthState: HealthState = .notDetermined
    private(set) var lastError: String?
    private var heartRateSamples: [Double] = []

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?

    override init() {
        super.init()
        refreshState()
    }

    var averageHeartRate: Double {
        heartRateSamples.isEmpty ? 0 : heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
    }

    func refreshState() {
        guard HKHealthStore.isHealthDataAvailable() else { healthState = .unavailable; return }
        switch store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .sharingAuthorized: healthState = .authorized
        case .sharingDenied: healthState = .denied
        default: healthState = .notDetermined
        }
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { healthState = .unavailable; return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate)]
        let read: Set<HKObjectType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate)]
        do {
            try await store.requestAuthorization(toShare: share, read: read)
        } catch {
            lastError = error.localizedDescription
        }
        refreshState()
    }

    /// Starts collecting. Without Health authorisation the workout is still recorded in FitTrack.
    func start(at date: Date) async {
        if healthState == .notDetermined { await requestAuthorization() }
        guard healthState == .authorized else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            heartRateSamples = []
            heartRate = 0
            activeEnergy = 0
            session.startActivity(with: date)
            try await builder.beginCollection(at: date)
            isCollecting = true
        } catch {
            lastError = "Impossible de démarrer l'enregistrement Santé : \(error.localizedDescription)"
            session = nil
            builder = nil
        }
    }

    /// Reattaches to a workout after the app was relaunched by the system (crash recovery).
    func recover() async {
        do {
            let recoveredSession: HKWorkoutSession? = try await store.recoverActiveWorkoutSession()
            guard let recovered = recoveredSession else { return }
            let builder = recovered.associatedWorkoutBuilder()
            recovered.delegate = self
            builder.delegate = self
            session = recovered
            self.builder = builder
            isCollecting = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    /// Ends the workout and saves it to Apple Health. Returns true when saved.
    func end(at date: Date) async -> Bool {
        guard let session, let builder else { return false }
        session.end()
        defer {
            self.session = nil
            self.builder = nil
            isCollecting = false
        }
        do {
            try await builder.endCollection(at: date)
            _ = try await builder.finishWorkout()
            return true
        } catch {
            lastError = "La séance n'a pas pu être enregistrée dans Santé : \(error.localizedDescription)"
            return false
        }
    }

    /// Abandons the workout without saving it to Health.
    func discard() {
        session?.end()
        builder?.discardWorkout()
        session = nil
        builder = nil
        isCollecting = false
    }

    fileprivate func update(heartRate: Double?, energy: Double?) {
        if let heartRate, heartRate > 0 {
            self.heartRate = heartRate
            heartRateSamples.append(heartRate)
        }
        if let energy { activeEnergy = energy }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.lastError = message }
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var hr: Double?
        var kcal: Double?
        let hrType = HKQuantityType(.heartRate)
        let energyType = HKQuantityType(.activeEnergyBurned)
        if collectedTypes.contains(hrType) {
            hr = workoutBuilder.statistics(for: hrType)?.mostRecentQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        if collectedTypes.contains(energyType) {
            kcal = workoutBuilder.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        }
        Task { @MainActor in self.update(heartRate: hr, energy: kcal) }
    }
}
