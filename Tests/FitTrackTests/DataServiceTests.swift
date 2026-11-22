import XCTest
import SwiftData
@testable import FitTrack

@MainActor
final class DataServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var service: DataService!

    override func setUp() async throws {
        container = try Persistence.makeContainer(inMemory: true)
        service = DataService(container.mainContext)
    }

    override func tearDown() async throws {
        service = nil
        container = nil
    }

    func testEnsureProfileIsIdempotent() {
        let a = service.ensureProfile()
        let b = service.ensureProfile()
        XCTAssertEqual(a.uuid, b.uuid)
        XCTAssertEqual(a.heightCm, 177)
        XCTAssertEqual(a.weightKg, 77)
        XCTAssertTrue(a.halalOnly)
    }

    func testSeedProgramCreatesFiveDays() {
        service.seedProgramIfNeeded(sessionsPerWeek: 5)
        service.seedProgramIfNeeded(sessionsPerWeek: 5)
        let templates = service.templates()
        XCTAssertEqual(templates.count, 5)
        XCTAssertEqual(templates.first?.orderedExercises.count, 6)
        service.replaceProgram(sessionsPerWeek: 3)
        XCTAssertEqual(service.templates().count, 3)
    }

    func testWorkoutLifecycleAndProgression() throws {
        service.seedProgramIfNeeded(sessionsPerWeek: 5)
        let template = try XCTUnwrap(service.templates().first)
        let session = service.startSession(template: template, device: .iPhone)
        XCTAssertEqual(service.unfinishedSession()?.uuid, session.uuid)

        let bench = try XCTUnwrap(session.orderedExercises.first)
        XCTAssertEqual(bench.exerciseId, "bench_press")
        XCTAssertEqual(bench.orderedSets.count, 3)
        XCTAssertEqual(bench.orderedSets.first?.weightKg, 40)

        for set in bench.orderedSets {
            set.reps = 8
            service.completeSet(set)
        }
        session.pause(at: session.startDate.addingTimeInterval(60))
        session.resume(at: session.startDate.addingTimeInterval(120))
        session.finish(at: session.startDate.addingTimeInterval(600))
        service.save()

        XCTAssertNil(service.unfinishedSession())
        XCTAssertEqual(session.elapsed(), 540, accuracy: 0.001)
        XCTAssertEqual(session.totalVolume, 3 * 8 * 40)

        // Next time, every set reached the top of the 6–8 range: +2.5 kg.
        let next = service.startSession(template: template, device: .iPhone)
        XCTAssertEqual(next.orderedExercises.first?.orderedSets.first?.weightKg, 42.5)
    }

    func testAddAndRemoveExerciseAndSets() throws {
        let session = service.startSession(template: nil, device: .iPhone)
        let log = service.addExercise("lateral_raise", to: session)
        XCTAssertEqual(log.orderedSets.count, 3)
        let extra = service.addSet(to: log)
        XCTAssertEqual(log.orderedSets.count, 4)
        service.removeSet(extra)
        XCTAssertEqual(log.orderedSets.count, 3)
        service.removeExercise(log)
        XCTAssertTrue(session.orderedExercises.isEmpty)
    }

    func testImportSessionIsIdempotent() throws {
        let dto = SessionDTO(uuid: UUID(), templateUUID: nil, name: "Montre", startDate: .now.addingTimeInterval(-1800),
                             endDate: .now, pausedSeconds: 0, activeEnergyKcal: 210, averageHeartRate: 118,
                             savedToHealth: true, device: WorkoutDevice.watch.rawValue,
                             exercises: [ExerciseLogDTO(uuid: UUID(), exerciseId: "back_squat", order: 0, restSeconds: 120,
                                                        repMin: 6, repMax: 8,
                                                        sets: [SetDTO(uuid: UUID(), order: 0, reps: 8, weightKg: 60,
                                                                      isCompleted: true, completedAt: .now)])])
        XCTAssertTrue(service.importSession(dto))
        XCTAssertFalse(service.importSession(dto), "Second import must be ignored")
        XCTAssertEqual(service.finishedSessions().count, 1)
        XCTAssertEqual(service.finishedSessions().first?.device, .watch)
        XCTAssertEqual(service.allSamples(exerciseId: "back_squat").first?.weightKg, 60)
    }

    func testSyncPayloadRoundTrip() throws {
        service.seedProgramIfNeeded(sessionsPerWeek: 4)
        let program = ProgramDTO(templates: service.templates().map(\.dto), suggestions: ["bench_press": WeightSuggestionDTO(weightKg: 45, reps: 6, basedOn: .now)], generatedAt: .now)
        let dict = try SyncMessage.encode(.program, program)
        XCTAssertEqual(SyncMessage.kind(of: dict), .program)
        let decoded = try SyncMessage.decode(ProgramDTO.self, from: dict)
        XCTAssertEqual(decoded.templates.count, 4)
        XCTAssertEqual(decoded.suggestions["bench_press"]?.weightKg, 45)

        // Applying the program on another store reproduces the same templates.
        let otherContainer = try Persistence.makeContainer(inMemory: true)
        let other = DataService(otherContainer.mainContext)
        other.applyProgram(decoded)
        other.applyProgram(decoded)
        XCTAssertEqual(other.templates().map(\.uuid), service.templates().map(\.uuid))
        XCTAssertEqual(other.templates().first?.orderedExercises.count, service.templates().first?.orderedExercises.count)
    }

    func testWeightLoggingUpdatesProfileAndKeepsOnePerDay() {
        let profile = service.ensureProfile()
        service.logWeight(76.4)
        service.logWeight(76.2)
        XCTAssertEqual(service.weightEntries().count, 1)
        XCTAssertEqual(profile.weightKg, 76.2)
        service.logWeight(78, on: .now.addingTimeInterval(-86400 * 10))
        XCTAssertEqual(service.weightEntries().count, 2)
        XCTAssertEqual(profile.weightKg, 76.2, "An older entry must not overwrite the current weight")
    }

    func testFoodJournalTotals() {
        let chicken = GenericFoodDatabase.search("poulet").first!
        let rice = GenericFoodDatabase.search("riz basmati").first!
        service.addFood(chicken, grams: 150, meal: .lunch, day: .now)
        service.addFood(rice, grams: 200, meal: .lunch, day: .now)
        let entries = service.foodEntries(on: .now)
        XCTAssertEqual(entries.count, 2)
        let total = entries.map(\.macros).total
        XCTAssertEqual(total.protein, chicken.per100g.protein * 1.5 + rice.per100g.protein * 2, accuracy: 0.01)
        XCTAssertEqual(service.recentFoods().count, 2)
        XCTAssertTrue(service.foodEntries(on: .now.addingTimeInterval(-86400 * 2)).isEmpty)
    }

    func testRemoveDuplicates() {
        let a = WeightEntry(weightKg: 77)
        let b = WeightEntry(weightKg: 77)
        b.uuid = a.uuid
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        service.save()
        service.removeDuplicates()
        XCTAssertEqual(service.weightEntries().count, 1)
    }

    func testGenericFoodSearchHasNoPork() {
        XCTAssertTrue(GenericFoodDatabase.search("porc").isEmpty)
        XCTAssertTrue(GenericFoodDatabase.search("jambon").isEmpty)
        XCTAssertFalse(GenericFoodDatabase.search("oeuf").isEmpty)
        XCTAssertFalse(GenericFoodDatabase.search("Œuf").isEmpty)
    }
}
