import Foundation
import HealthKit
import Observation

/// Apple Health integration for the iPhone.
/// FitTrack only reports "connected" when the system says it may write data; read permission
/// cannot be queried (Apple hides it for privacy), so reads simply return no data when denied.
@MainActor
@Observable
final class HealthKitService {
    enum Status: Equatable {
        case unavailable
        case notDetermined
        case authorized
        case denied
        case partiallyAuthorized

        var label: String {
            switch self {
            case .unavailable: return "Non disponible sur cet appareil"
            case .notDetermined: return "Non connecté"
            case .authorized: return "Connecté"
            case .denied: return "Accès refusé"
            case .partiallyAuthorized: return "Accès partiel"
            }
        }
    }

    private(set) var status: Status = .notDetermined
    private(set) var todaySteps: Double?
    private(set) var todayActiveEnergy: Double?
    private(set) var todayExerciseMinutes: Double?
    private(set) var latestBodyMass: (kg: Double, date: Date)?
    private(set) var lastError: String?

    @ObservationIgnored private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(),
         HKQuantityType(.bodyMass),
         HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.dietaryEnergyConsumed),
         HKQuantityType(.dietaryProtein),
         HKQuantityType(.dietaryCarbohydrates),
         HKQuantityType(.dietaryFatTotal)]
    }

    private var readTypes: Set<HKObjectType> {
        [HKObjectType.workoutType(),
         HKQuantityType(.bodyMass),
         HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.heartRate),
         HKQuantityType(.stepCount),
         HKQuantityType(.appleExerciseTime)]
    }

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        guard isAvailable else { status = .unavailable; return }
        let statuses = shareTypes.map { store.authorizationStatus(for: $0) }
        if statuses.allSatisfy({ $0 == .sharingAuthorized }) {
            status = .authorized
        } else if statuses.contains(.sharingAuthorized) {
            status = .partiallyAuthorized
        } else if statuses.allSatisfy({ $0 == .notDetermined }) {
            status = .notDetermined
        } else {
            status = .denied
        }
    }

    var canWrite: Bool { status == .authorized || status == .partiallyAuthorized }

    private func canShare(_ type: HKObjectType) -> Bool {
        isAvailable && store.authorizationStatus(for: type) == .sharingAuthorized
    }

    /// Shows the system permission sheet (only the first time; afterwards the user changes it in Settings).
    func requestAuthorization() async {
        guard isAvailable else { status = .unavailable; return }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            lastError = nil
        } catch {
            lastError = "La demande d'accès à Santé a échoué : \(error.localizedDescription)"
        }
        refreshStatus()
        await refreshToday()
    }

    // MARK: Reading

    func refreshToday() async {
        guard isAvailable, status != .notDetermined else { return }
        let start = Calendar.fitTrack.startOfDay(for: .now)
        todaySteps = await sum(.stepCount, unit: .count(), from: start)
        todayActiveEnergy = await sum(.activeEnergyBurned, unit: .kilocalorie(), from: start)
        todayExerciseMinutes = await sum(.appleExerciseTime, unit: .minute(), from: start)
        latestBodyMass = await latestSample(.bodyMass, unit: .gramUnit(with: .kilo))
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date = .now) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: HKQuantityType(id), predicate: predicate),
            options: .cumulativeSum)
        do {
            return try await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: unit)
        } catch {
            return nil
        }
    }

    private func latestSample(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> (Double, Date)? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(id), predicate: nil)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1)
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return (sample.quantity.doubleValue(for: unit), sample.endDate)
    }

    /// Average heart rate between two dates (e.g. recorded by the Apple Watch during a workout).
    func averageHeartRate(from start: Date, to end: Date) async -> Double? {
        guard isAvailable else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: HKQuantityType(.heartRate), predicate: predicate),
            options: .discreteAverage)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try? await descriptor.result(for: store)?.averageQuantity()?.doubleValue(for: unit)
    }

    func activeEnergy(from start: Date, to end: Date) async -> Double? {
        await sum(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
    }

    // MARK: Writing

    /// Saves a strength workout recorded on the iPhone.
    func saveWorkout(start: Date, end: Date, activeEnergyKcal: Double?) async throws {
        guard canShare(HKObjectType.workoutType()) else { throw HealthError.notAuthorized }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)
        if let kcal = activeEnergyKcal, kcal > 0, canShare(HKQuantityType(.activeEnergyBurned)) {
            let sample = HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                          quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                          start: start, end: end)
            try await builder.addSamples([sample])
        }
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }

    func saveBodyMass(_ kg: Double, date: Date) async throws {
        let type = HKQuantityType(.bodyMass)
        guard canShare(type) else { throw HealthError.notAuthorized }
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: date, end: date)
        try await store.save(sample)
    }

    /// Saves a food entry as a "food" correlation (energy + macronutrients).
    func saveFood(name: String, macros: Macros, date: Date, id: UUID) async throws {
        guard canShare(HKQuantityType(.dietaryEnergyConsumed)) else { throw HealthError.notAuthorized }
        let metadata: [String: Any] = [HKMetadataKeyFoodType: name, HKMetadataKeyExternalUUID: id.uuidString]
        var samples: Set<HKSample> = []
        func add(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double) {
            let type = HKQuantityType(id)
            guard value > 0, canShare(type) else { return }
            samples.insert(HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: value),
                                            start: date, end: date, metadata: metadata))
        }
        add(.dietaryEnergyConsumed, .kilocalorie(), macros.kcal)
        add(.dietaryProtein, .gram(), macros.protein)
        add(.dietaryCarbohydrates, .gram(), macros.carbs)
        add(.dietaryFatTotal, .gram(), macros.fat)
        guard !samples.isEmpty else { return }
        guard let foodType = HKObjectType.correlationType(forIdentifier: .food) else { return }
        let correlation = HKCorrelation(type: foodType, start: date, end: date,
                                        objects: samples, metadata: metadata)
        try await store.save(correlation)
    }

    /// Removes the Health samples written for a food entry that the user deleted.
    func deleteFood(id: UUID) async {
        guard canShare(HKQuantityType(.dietaryEnergyConsumed)) else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID,
                                                    allowedValues: [id.uuidString])
        for typeId in [HKQuantityTypeIdentifier.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal] {
            let type = HKQuantityType(typeId)
            guard canShare(type) else { continue }
            _ = try? await store.deleteObjects(of: type, predicate: predicate)
        }
    }
}

enum HealthError: LocalizedError {
    case notAuthorized
    var errorDescription: String? {
        "FitTrack n'est pas autorisé à écrire dans Santé. Activez l'accès dans Réglages › Santé › Accès aux données et appareils › FitTrack."
    }
}
