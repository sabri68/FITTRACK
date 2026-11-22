import Foundation
import SwiftData

// All models follow CloudKit rules so that private iCloud sync can be switched on
// without a migration: every stored property has a default value, relationships are
// optional, and there are no unique constraints (de-duplication uses `uuid`).

// MARK: - Profile

@Model
final class UserProfile {
    var uuid: UUID = UUID()
    var firstName: String = ""
    var sexRaw: String = Sex.male.rawValue
    var age: Int = 24
    var heightCm: Double = 177
    var weightKg: Double = 77
    var targetWeightKg: Double = 75
    var levelRaw: String = FitnessLevel.beginner.rawValue
    var goalRaw: String = FitnessGoal.recomposition.rawValue
    var sessionsPerWeek: Int = 5
    var halalOnly: Bool = true
    /// When > 0, overrides the computed calorie target.
    var customCalories: Int = 0
    var onboardingCompleted: Bool = false
    var healthKitPrompted: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }
    var level: FitnessLevel {
        get { FitnessLevel(rawValue: levelRaw) ?? .beginner }
        set { levelRaw = newValue.rawValue }
    }
    var goal: FitnessGoal {
        get { FitnessGoal(rawValue: goalRaw) ?? .recomposition }
        set { goalRaw = newValue.rawValue }
    }

    var nutritionInput: NutritionInput {
        NutritionInput(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
                       sessionsPerWeek: sessionsPerWeek, goal: goal, customCalories: customCalories)
    }

    var targets: NutritionTargets { NutritionCalculator.targets(for: nutritionInput) }
}

// MARK: - Body weight

@Model
final class WeightEntry {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double = 0
    var savedToHealth: Bool = false

    init(date: Date = .now, weightKg: Double) {
        self.date = date
        self.weightKg = weightKg
    }
}

// MARK: - Training program

@Model
final class WorkoutTemplate {
    var uuid: UUID = UUID()
    var name: String = ""
    var focus: String = ""
    var dayIndex: Int = 0
    var symbol: String = "figure.strengthtraining.traditional"
    var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]? = []

    init(name: String, focus: String, dayIndex: Int, symbol: String) {
        self.name = name
        self.focus = focus
        self.dayIndex = dayIndex
        self.symbol = symbol
    }

    var orderedExercises: [TemplateExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class TemplateExercise {
    var uuid: UUID = UUID()
    var exerciseId: String = ""
    var order: Int = 0
    var targetSets: Int = 3
    var repMin: Int = 8
    var repMax: Int = 12
    var restSeconds: Int = 90
    var startWeightKg: Double = 0
    var template: WorkoutTemplate?

    init(exerciseId: String, order: Int, targetSets: Int, repMin: Int, repMax: Int, restSeconds: Int, startWeightKg: Double) {
        self.exerciseId = exerciseId
        self.order = order
        self.targetSets = targetSets
        self.repMin = repMin
        self.repMax = repMax
        self.restSeconds = restSeconds
        self.startWeightKg = startWeightKg
    }

    var exercise: Exercise? { ExerciseCatalog.exercise(id: exerciseId) }
    var repRangeLabel: String { repMin == repMax ? "\(repMin)" : "\(repMin)–\(repMax)" }
}

// MARK: - Workout sessions

@Model
final class WorkoutSession {
    var uuid: UUID = UUID()
    var templateUUID: UUID?
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date?
    /// Total time spent paused, excluding the current pause.
    var pausedSeconds: Double = 0
    var pauseStartedAt: Date?
    var stateRaw: String = WorkoutState.active.rawValue
    var deviceRaw: String = WorkoutDevice.iPhone.rawValue
    var activeEnergyKcal: Double = 0
    var averageHeartRate: Double = 0
    var savedToHealth: Bool = false
    var syncedToPhone: Bool = false
    var notes: String = ""
    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
    var exercises: [ExerciseLog]? = []

    init(name: String, templateUUID: UUID?, device: WorkoutDevice, startDate: Date = .now) {
        self.name = name
        self.templateUUID = templateUUID
        self.deviceRaw = device.rawValue
        self.startDate = startDate
    }

    var state: WorkoutState {
        get { WorkoutState(rawValue: stateRaw) ?? .finished }
        set { stateRaw = newValue.rawValue }
    }
    var device: WorkoutDevice { WorkoutDevice(rawValue: deviceRaw) ?? .iPhone }

    var orderedExercises: [ExerciseLog] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var timing: WorkoutTiming {
        WorkoutTiming(startDate: startDate, endDate: endDate, pausedSeconds: pausedSeconds, pauseStartedAt: pauseStartedAt)
    }

    func elapsed(at date: Date = .now) -> TimeInterval { timing.elapsed(at: date) }

    var completedSets: [SetLog] {
        orderedExercises.flatMap { $0.orderedSets.filter(\.isCompleted) }
    }

    /// Total volume (kg × reps) of completed sets.
    var totalVolume: Double {
        completedSets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    func pause(at date: Date = .now) {
        guard state == .active else { return }
        pauseStartedAt = date
        state = .paused
    }

    func resume(at date: Date = .now) {
        guard state == .paused else { return }
        if let p = pauseStartedAt { pausedSeconds += max(0, date.timeIntervalSince(p)) }
        pauseStartedAt = nil
        state = .active
    }

    func finish(at date: Date = .now) {
        if state == .paused { resume(at: date) }
        endDate = date
        state = .finished
    }
}

@Model
final class ExerciseLog {
    var uuid: UUID = UUID()
    var exerciseId: String = ""
    var order: Int = 0
    var restSeconds: Int = 90
    var repMin: Int = 8
    var repMax: Int = 12
    var session: WorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \SetLog.exerciseLog)
    var sets: [SetLog]? = []

    init(exerciseId: String, order: Int, restSeconds: Int, repMin: Int, repMax: Int) {
        self.exerciseId = exerciseId
        self.order = order
        self.restSeconds = restSeconds
        self.repMin = repMin
        self.repMax = repMax
    }

    var exercise: Exercise? { ExerciseCatalog.exercise(id: exerciseId) }
    var displayName: String { exercise?.name ?? "Exercice" }

    var orderedSets: [SetLog] {
        (sets ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class SetLog {
    var uuid: UUID = UUID()
    var order: Int = 0
    var reps: Int = 0
    var weightKg: Double = 0
    var isCompleted: Bool = false
    var completedAt: Date?
    var exerciseLog: ExerciseLog?

    init(order: Int, reps: Int, weightKg: Double) {
        self.order = order
        self.reps = reps
        self.weightKg = weightKg
    }
}

// MARK: - Nutrition

@Model
final class FoodEntry {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var mealRaw: String = MealType.snack.rawValue
    var name: String = ""
    var brand: String = ""
    var barcode: String = ""
    var quantityGrams: Double = 100
    var kcalPer100g: Double = 0
    var proteinPer100g: Double = 0
    var carbsPer100g: Double = 0
    var fatPer100g: Double = 0
    var halalRaw: String = HalalStatus.unknown.rawValue
    var sourceRaw: String = FoodSource.manual.rawValue
    var savedToHealth: Bool = false
    var createdAt: Date = Date()

    init(food: FoodItem, quantityGrams: Double, meal: MealType, date: Date) {
        self.date = date
        self.mealRaw = meal.rawValue
        self.name = food.name
        self.brand = food.brand
        self.barcode = food.barcode
        self.quantityGrams = quantityGrams
        self.kcalPer100g = food.per100g.kcal
        self.proteinPer100g = food.per100g.protein
        self.carbsPer100g = food.per100g.carbs
        self.fatPer100g = food.per100g.fat
        self.halalRaw = food.halal.rawValue
        self.sourceRaw = food.source.rawValue
    }

    var meal: MealType {
        get { MealType(rawValue: mealRaw) ?? .snack }
        set { mealRaw = newValue.rawValue }
    }
    var halal: HalalStatus { HalalStatus(rawValue: halalRaw) ?? .unknown }
    var source: FoodSource { FoodSource(rawValue: sourceRaw) ?? .manual }

    var per100g: Macros {
        Macros(kcal: kcalPer100g, protein: proteinPer100g, carbs: carbsPer100g, fat: fatPer100g)
    }
    var macros: Macros { per100g.scaled(toGrams: quantityGrams) }

    /// Rebuilds a reusable food item (used for "recent foods").
    var asFoodItem: FoodItem {
        FoodItem(id: barcode.isEmpty ? "entry-\(name)-\(brand)" : barcode, name: name, brand: brand, barcode: barcode,
                 per100g: per100g, servingGrams: nil, halal: halal, halalReasons: [], source: source)
    }
}
