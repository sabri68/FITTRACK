import Foundation

/// Energy and macronutrients.
struct Macros: Codable, Hashable {
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    static let zero = Macros(kcal: 0, protein: 0, carbs: 0, fat: 0)

    func scaled(toGrams grams: Double) -> Macros {
        let f = grams / 100
        return Macros(kcal: kcal * f, protein: protein * f, carbs: carbs * f, fat: fat * f)
    }

    static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(kcal: lhs.kcal + rhs.kcal, protein: lhs.protein + rhs.protein,
               carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat)
    }

    static func / (lhs: Macros, rhs: Double) -> Macros {
        guard rhs > 0 else { return .zero }
        return Macros(kcal: lhs.kcal / rhs, protein: lhs.protein / rhs, carbs: lhs.carbs / rhs, fat: lhs.fat / rhs)
    }

    /// Validates values entered per 100 g.
    var isPlausiblePer100g: Bool {
        let values = [kcal, protein, carbs, fat]
        guard values.allSatisfy({ $0 >= 0 && $0.isFinite }) else { return false }
        return kcal <= 950 && protein + carbs + fat <= 100.5
    }
}

extension Sequence where Element == Macros {
    var total: Macros { reduce(.zero, +) }
}

struct NutritionInput: Equatable {
    var sex: Sex
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var sessionsPerWeek: Int
    var goal: FitnessGoal
    var customCalories: Int
}

struct NutritionTargets: Equatable {
    var bmr: Double
    var maintenance: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    var macros: Macros { Macros(kcal: calories, protein: protein, carbs: carbs, fat: fat) }
}

enum NutritionCalculator {
    /// Mifflin–St Jeor basal metabolic rate.
    static func bmr(sex: Sex, age: Int, heightCm: Double, weightKg: Double) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    static func targets(for input: NutritionInput) -> NutritionTargets {
        let bmr = bmr(sex: input.sex, age: input.age, heightCm: input.heightCm, weightKg: input.weightKg)
        let maintenance = bmr * ActivityLevel.from(sessionsPerWeek: input.sessionsPerWeek).factor
        var calories = input.customCalories > 0
            ? Double(input.customCalories)
            : (maintenance * input.goal.calorieFactor / 10).rounded() * 10
        // Never recommend less than the BMR-based safety floor.
        calories = max(calories, input.customCalories > 0 ? 1000 : max(1200, bmr))

        let protein = (input.weightKg * input.goal.proteinPerKg).rounded()
        let fat = max((input.weightKg * 0.9).rounded(), (calories * 0.20 / 9).rounded())
        let carbs = max(0, ((calories - protein * 4 - fat * 9) / 4).rounded())
        return NutritionTargets(bmr: bmr, maintenance: maintenance, calories: calories,
                                protein: protein, carbs: carbs, fat: fat)
    }
}
