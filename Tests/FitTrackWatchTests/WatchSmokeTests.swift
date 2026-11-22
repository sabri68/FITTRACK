import XCTest
import SwiftData
@testable import FitTrackWatch

@MainActor
final class WatchSharedLogicTests: XCTestCase {
    func testAppName() {
        XCTAssertEqual(AppInfo.name, "FitTrack")
    }

    func testWatchStoreSeedsProgramAndRecordsWorkout() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let service = DataService(container.mainContext)
        service.seedProgramIfNeeded(sessionsPerWeek: 5)
        let template = try XCTUnwrap(service.templates().first)
        let session = service.startSession(template: template, device: .watch)
        let firstSet = try XCTUnwrap(session.orderedExercises.first?.orderedSets.first)
        service.completeSet(firstSet)
        session.finish()
        service.save()
        XCTAssertEqual(service.finishedSessions().count, 1)
        let dto = session.dto
        XCTAssertEqual(dto.device, WorkoutDevice.watch.rawValue)
        XCTAssertEqual(dto.exercises.first?.sets.first?.isCompleted, true)
        // The payload sent to the iPhone survives encoding.
        let dict = try SyncMessage.encode(.session, dto)
        let decoded = try SyncMessage.decode(SessionDTO.self, from: dict)
        XCTAssertEqual(decoded.uuid, dto.uuid)
        XCTAssertEqual(decoded.name, dto.name)
        XCTAssertEqual(decoded.exercises.map(\.exerciseId), dto.exercises.map(\.exerciseId))
        XCTAssertEqual(decoded.exercises.flatMap(\.sets).map(\.isCompleted), dto.exercises.flatMap(\.sets).map(\.isCompleted))
        XCTAssertEqual(decoded.startDate.timeIntervalSince1970, dto.startDate.timeIntervalSince1970, accuracy: 0.001)
    }

    func testPhoneSuggestionWinsWhenNewer() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let service = DataService(container.mainContext)
        service.seedProgramIfNeeded(sessionsPerWeek: 5)
        let item = try XCTUnwrap(service.templates().first?.orderedExercises.first)
        let s = service.suggestion(for: item, phoneSuggestions: [item.exerciseId: WeightSuggestionDTO(weightKg: 47.5, reps: 7, basedOn: .now)])
        XCTAssertEqual(s.weightKg, 47.5)
        XCTAssertEqual(s.reps, 7)
    }
}
