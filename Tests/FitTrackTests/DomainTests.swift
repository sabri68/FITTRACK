import XCTest
@testable import FitTrack

final class NutritionCalculatorTests: XCTestCase {
    private let profileInput = NutritionInput(sex: .male, age: 24, heightCm: 177, weightKg: 77,
                                              sessionsPerWeek: 5, goal: .recomposition, customCalories: 0)

    func testBMRMifflinStJeorMale() {
        let bmr = NutritionCalculator.bmr(sex: .male, age: 24, heightCm: 177, weightKg: 77)
        XCTAssertEqual(bmr, 1761.25, accuracy: 0.01)
    }

    func testRecompositionTargetsForDefaultProfile() {
        let t = NutritionCalculator.targets(for: profileInput)
        XCTAssertEqual(t.maintenance, 1761.25 * 1.55, accuracy: 0.5)
        XCTAssertEqual(t.calories, 2460)
        XCTAssertEqual(t.protein, 154)
        XCTAssertEqual(t.fat, 69)
        // Macros must add up to the calorie target (±1 g rounding).
        XCTAssertEqual(t.protein * 4 + t.carbs * 4 + t.fat * 9, t.calories, accuracy: 6)
    }

    func testCustomCaloriesOverrideComputedTarget() {
        var input = profileInput
        input.customCalories = 2200
        XCTAssertEqual(NutritionCalculator.targets(for: input).calories, 2200)
    }

    func testGoalOrdering() {
        func cals(_ goal: FitnessGoal) -> Double {
            var input = profileInput
            input.goal = goal
            return NutritionCalculator.targets(for: input).calories
        }
        XCTAssertLessThan(cals(.loseFat), cals(.recomposition))
        XCTAssertLessThan(cals(.recomposition), cals(.maintain))
        XCTAssertLessThan(cals(.maintain), cals(.buildMuscle))
    }

    func testMacrosScaling() {
        let per100 = Macros(kcal: 200, protein: 20, carbs: 10, fat: 5)
        let scaled = per100.scaled(toGrams: 150)
        XCTAssertEqual(scaled.kcal, 300, accuracy: 0.001)
        XCTAssertEqual(scaled.protein, 30, accuracy: 0.001)
        XCTAssertTrue(per100.isPlausiblePer100g)
        XCTAssertFalse(Macros(kcal: 2000, protein: 0, carbs: 0, fat: 0).isPlausiblePer100g)
    }
}

final class HalalAnalyzerTests: XCTestCase {
    func testDetectsPork() {
        let (status, reasons) = HalalAnalyzer.classify(labelsTags: [], ingredientsTags: ["en:pork", "en:salt"],
                                                       analysisTags: [], ingredientsText: "", productName: "Saucisson")
        XCTAssertEqual(status, .potentiallyNonHalal)
        XCTAssertTrue(reasons.contains("porc"))
    }

    func testDetectsGelatinAndAlcoholInFrenchText() {
        let reasons = HalalAnalyzer.nonHalalReasons(in: ["sucre, gélatine de bœuf, arôme, alcool"])
        XCTAssertTrue(reasons.contains { $0.contains("gélatine") })
        XCTAssertTrue(reasons.contains("alcool"))
    }

    func testWordBoundaries() {
        // "champignon" contains "ham"/"pig" fragments, "vinaigre de vin" is not wine.
        XCTAssertTrue(HalalAnalyzer.nonHalalReasons(in: ["champignons de paris, vinaigre de vin, vinaigrette"]).isEmpty)
    }

    func testDeclaredHalalLabel() {
        let (status, _) = HalalAnalyzer.classify(labelsTags: ["en:halal"], ingredientsTags: ["en:chicken"],
                                                 analysisTags: [], ingredientsText: "", productName: "Nuggets")
        XCTAssertEqual(status, .declaredHalal)
    }

    func testMeatWithoutLabelDependsOnOrigin() {
        let (status, _) = HalalAnalyzer.classify(labelsTags: [], ingredientsTags: ["en:beef"],
                                                 analysisTags: [], ingredientsText: "", productName: "Steak")
        XCTAssertEqual(status, .dependsOnOrigin)
    }

    func testUnknownWithoutInformation() {
        let (status, _) = HalalAnalyzer.classify(labelsTags: [], ingredientsTags: [], analysisTags: [],
                                                 ingredientsText: "", productName: "Biscuits")
        XCTAssertEqual(status, .unknown)
    }

    func testPlantBased() {
        let (status, _) = HalalAnalyzer.classify(labelsTags: [], ingredientsTags: ["en:oat", "en:water"],
                                                 analysisTags: ["en:vegan", "en:vegetarian"], ingredientsText: "avoine, eau",
                                                 productName: "Boisson avoine")
        XCTAssertEqual(status, .plantBased)
    }
}

final class StrengthMathTests: XCTestCase {
    func testEpley() {
        XCTAssertEqual(StrengthMath.estimatedOneRepMax(weightKg: 100, reps: 1), 100)
        XCTAssertEqual(StrengthMath.estimatedOneRepMax(weightKg: 60, reps: 10), 80, accuracy: 0.001)
        XCTAssertEqual(StrengthMath.estimatedOneRepMax(weightKg: 0, reps: 10), 0)
    }

    func testProgressionIncreasesWeightWhenTopOfRangeReached() {
        let sets = (0..<3).map { _ in SetSample(date: .now, weightKg: 40, reps: 8) }
        let s = StrengthMath.suggestion(previousSets: sets, repMin: 6, repMax: 8, isCompound: true, isLowerBody: false, fallbackWeight: 30)
        XCTAssertEqual(s.weightKg, 42.5)
        XCTAssertEqual(s.reps, 6)
        XCTAssertEqual(s.kind, .increaseWeight(by: 2.5))
    }

    func testProgressionLowerBodyIncrement() {
        let sets = [SetSample(date: .now, weightKg: 60, reps: 8), SetSample(date: .now, weightKg: 60, reps: 8)]
        let s = StrengthMath.suggestion(previousSets: sets, repMin: 6, repMax: 8, isCompound: true, isLowerBody: true, fallbackWeight: 0)
        XCTAssertEqual(s.weightKg, 65)
    }

    func testProgressionAddsRepsOtherwise() {
        let sets = [SetSample(date: .now, weightKg: 40, reps: 8), SetSample(date: .now, weightKg: 40, reps: 6)]
        let s = StrengthMath.suggestion(previousSets: sets, repMin: 6, repMax: 8, isCompound: true, isLowerBody: false, fallbackWeight: 30)
        XCTAssertEqual(s.weightKg, 40)
        XCTAssertEqual(s.reps, 7)
        XCTAssertEqual(s.kind, .addReps)
    }

    func testFirstTimeUsesFallback() {
        let s = StrengthMath.suggestion(previousSets: [], repMin: 8, repMax: 12, isCompound: false, isLowerBody: false, fallbackWeight: 12)
        XCTAssertEqual(s.weightKg, 12)
        XCTAssertEqual(s.kind, .firstTime)
    }

    func testPersonalRecord() {
        let samples = [SetSample(date: .now, weightKg: 50, reps: 10), SetSample(date: .now, weightKg: 60, reps: 3)]
        let pr = StrengthMath.personalRecord(exerciseId: "bench_press", samples: samples)
        XCTAssertEqual(pr?.maxWeightKg, 60)
        XCTAssertEqual(pr?.bestEstimatedOneRepMax ?? 0, 66.67, accuracy: 0.01)
    }
}

final class TimingAndStatsTests: XCTestCase {
    func testElapsedExcludesPauses() {
        let start = Date(timeIntervalSince1970: 0)
        let t = WorkoutTiming(startDate: start, endDate: nil, pausedSeconds: 60, pauseStartedAt: nil)
        XCTAssertEqual(t.elapsed(at: start.addingTimeInterval(600)), 540)
        let paused = WorkoutTiming(startDate: start, endDate: nil, pausedSeconds: 0, pauseStartedAt: start.addingTimeInterval(300))
        XCTAssertEqual(paused.elapsed(at: start.addingTimeInterval(900)), 300, "Time stops while paused")
    }

    func testWeeklyCountsAndStreak() {
        let cal = Calendar.fitTrack
        let now = cal.date(from: DateComponents(year: 2025, month: 3, day: 12, hour: 12))! // Wednesday
        let dates = [0, 7, 14].compactMap { cal.date(byAdding: .day, value: -$0, to: now) }
        let counts = TrainingStats.weeklyCounts(dates: dates, weeks: 4, now: now, calendar: cal)
        XCTAssertEqual(counts.map(\.count), [0, 1, 1, 1])
        XCTAssertEqual(TrainingStats.weekStreak(dates: dates, now: now, calendar: cal), 3)
    }

    func testFrenchFormatting() {
        XCTAssertEqual(FTFormat.weight(77.5), "77,5 kg")
        XCTAssertEqual(FTFormat.duration(3725), "1:02:05")
        XCTAssertEqual(FTFormat.duration(65), "01:05")
        XCTAssertEqual(FTFormat.parseDecimal("12,5"), 12.5)
        XCTAssertNil(FTFormat.parseDecimal("abc"))
        XCTAssertTrue(FTFormat.kcal(2460).hasSuffix("kcal"))
    }

    func testCatalogIntegrity() {
        XCTAssertEqual(Set(ExerciseCatalog.all.map(\.id)).count, ExerciseCatalog.all.count, "Exercise ids are unique")
        for days in [3, 4, 5] {
            let program = ProgramCatalog.program(sessionsPerWeek: days)
            XCTAssertEqual(program.count, days)
            for day in program {
                for item in day.items {
                    XCTAssertNotNil(ExerciseCatalog.exercise(id: item.exerciseId), "Unknown exercise \(item.exerciseId)")
                    XCTAssertLessThanOrEqual(item.repMin, item.repMax)
                }
            }
        }
    }
}
