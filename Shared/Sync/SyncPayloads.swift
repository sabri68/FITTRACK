import Foundation

/// Codable payloads exchanged between the iPhone and the Apple Watch with WatchConnectivity.
enum SyncMessage {
    static let kindKey = "kind"
    static let payloadKey = "payload"
    static let versionKey = "v"
    static let currentVersion = 1

    enum Kind: String {
        /// iPhone → Watch (application context): training program + weight suggestions.
        case program
        /// Watch → iPhone (user info transfer): a finished workout.
        case session
        /// Watch → iPhone (message): asks the phone to resend the program.
        case requestProgram
    }

    static func encode<T: Encodable>(_ kind: Kind, _ value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return [kindKey: kind.rawValue, versionKey: currentVersion, payloadKey: try encoder.encode(value)]
    }

    static func kind(of dict: [String: Any]) -> Kind? {
        (dict[kindKey] as? String).flatMap(Kind.init(rawValue:))
    }

    static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        guard let data = dict[payloadKey] as? Data else { throw SyncError.missingPayload }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(type, from: data)
    }
}

enum SyncError: LocalizedError {
    case missingPayload
    var errorDescription: String? { "Données de synchronisation incomplètes." }
}

struct WeightSuggestionDTO: Codable, Equatable {
    var weightKg: Double
    var reps: Int
    var basedOn: Date?
}

struct ProgramDTO: Codable, Equatable {
    var templates: [TemplateDTO]
    var suggestions: [String: WeightSuggestionDTO]
    var generatedAt: Date
}

struct TemplateDTO: Codable, Equatable {
    var uuid: UUID
    var name: String
    var focus: String
    var dayIndex: Int
    var symbol: String
    var exercises: [TemplateExerciseDTO]
}

struct TemplateExerciseDTO: Codable, Equatable {
    var exerciseId: String
    var order: Int
    var targetSets: Int
    var repMin: Int
    var repMax: Int
    var restSeconds: Int
    var startWeightKg: Double
}

struct SessionDTO: Codable, Equatable {
    var uuid: UUID
    var templateUUID: UUID?
    var name: String
    var startDate: Date
    var endDate: Date?
    var pausedSeconds: Double
    var activeEnergyKcal: Double
    var averageHeartRate: Double
    var savedToHealth: Bool
    var device: String
    var exercises: [ExerciseLogDTO]
}

struct ExerciseLogDTO: Codable, Equatable {
    var uuid: UUID
    var exerciseId: String
    var order: Int
    var restSeconds: Int
    var repMin: Int
    var repMax: Int
    var sets: [SetDTO]
}

struct SetDTO: Codable, Equatable {
    var uuid: UUID
    var order: Int
    var reps: Int
    var weightKg: Double
    var isCompleted: Bool
    var completedAt: Date?
}

// MARK: - Model ↔ DTO

extension WorkoutTemplate {
    var dto: TemplateDTO {
        TemplateDTO(uuid: uuid, name: name, focus: focus, dayIndex: dayIndex, symbol: symbol,
                    exercises: orderedExercises.map {
                        TemplateExerciseDTO(exerciseId: $0.exerciseId, order: $0.order, targetSets: $0.targetSets,
                                            repMin: $0.repMin, repMax: $0.repMax, restSeconds: $0.restSeconds,
                                            startWeightKg: $0.startWeightKg)
                    })
    }
}

extension WorkoutSession {
    var dto: SessionDTO {
        SessionDTO(uuid: uuid, templateUUID: templateUUID, name: name, startDate: startDate, endDate: endDate,
                   pausedSeconds: pausedSeconds, activeEnergyKcal: activeEnergyKcal, averageHeartRate: averageHeartRate,
                   savedToHealth: savedToHealth, device: deviceRaw,
                   exercises: orderedExercises.map { log in
                       ExerciseLogDTO(uuid: log.uuid, exerciseId: log.exerciseId, order: log.order,
                                      restSeconds: log.restSeconds, repMin: log.repMin, repMax: log.repMax,
                                      sets: log.orderedSets.map {
                                          SetDTO(uuid: $0.uuid, order: $0.order, reps: $0.reps, weightKg: $0.weightKg,
                                                 isCompleted: $0.isCompleted, completedAt: $0.completedAt)
                                      })
                   })
    }
}
