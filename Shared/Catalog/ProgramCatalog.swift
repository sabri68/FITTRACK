import Foundation

/// Plain description of a program day, used to seed SwiftData and for WatchConnectivity.
struct ProgramDayBlueprint: Equatable {
    struct Item: Equatable {
        var exerciseId: String
        var sets: Int
        var repMin: Int
        var repMax: Int
        var rest: Int
        var startWeight: Double
    }
    var name: String
    var focus: String
    var symbol: String
    var items: [Item]
}

enum ProgramCatalog {
    private typealias I = ProgramDayBlueprint.Item

    /// Beginner programs for 3, 4 or 5 sessions per week, oriented to muscle gain with fat loss.
    /// Starting weights are conservative suggestions for a beginner and are adjusted by the user.
    static func program(sessionsPerWeek: Int) -> [ProgramDayBlueprint] {
        switch sessionsPerWeek {
        case ..<4: return threeDays
        case 4: return fourDays
        default: return fiveDays
        }
    }

    static let fiveDays: [ProgramDayBlueprint] = [
        ProgramDayBlueprint(name: "Jour 1 · Haut du corps", focus: "Force – pectoraux, dos, épaules", symbol: "figure.strengthtraining.traditional", items: [
            I(exerciseId: "bench_press", sets: 3, repMin: 6, repMax: 8, rest: 150, startWeight: 40),
            I(exerciseId: "barbell_row", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 35),
            I(exerciseId: "db_shoulder_press", sets: 3, repMin: 8, repMax: 10, rest: 90, startWeight: 12),
            I(exerciseId: "lat_pulldown", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 40),
            I(exerciseId: "db_curl", sets: 2, repMin: 10, repMax: 12, rest: 60, startWeight: 8),
            I(exerciseId: "triceps_pushdown", sets: 2, repMin: 10, repMax: 12, rest: 60, startWeight: 20),
        ]),
        ProgramDayBlueprint(name: "Jour 2 · Bas du corps", focus: "Force – quadriceps, ischios, fessiers", symbol: "figure.strengthtraining.functional", items: [
            I(exerciseId: "back_squat", sets: 3, repMin: 6, repMax: 8, rest: 150, startWeight: 50),
            I(exerciseId: "romanian_deadlift", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 45),
            I(exerciseId: "leg_press", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 80),
            I(exerciseId: "leg_curl", sets: 3, repMin: 10, repMax: 12, rest: 75, startWeight: 25),
            I(exerciseId: "standing_calf_raise", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 40),
            I(exerciseId: "cable_crunch", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 20),
        ]),
        ProgramDayBlueprint(name: "Jour 3 · Poussée", focus: "Pectoraux, épaules, triceps", symbol: "figure.strengthtraining.traditional", items: [
            I(exerciseId: "incline_db_press", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 16),
            I(exerciseId: "overhead_press", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 25),
            I(exerciseId: "cable_fly", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 10),
            I(exerciseId: "lateral_raise", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 6),
            I(exerciseId: "dips", sets: 3, repMin: 8, repMax: 12, rest: 90, startWeight: 0),
            I(exerciseId: "skull_crusher", sets: 2, repMin: 10, repMax: 12, rest: 60, startWeight: 15),
        ]),
        ProgramDayBlueprint(name: "Jour 4 · Tirage", focus: "Dos, arrière d'épaules, biceps", symbol: "figure.rower", items: [
            I(exerciseId: "assisted_pullup", sets: 3, repMin: 6, repMax: 10, rest: 120, startWeight: 0),
            I(exerciseId: "one_arm_db_row", sets: 3, repMin: 8, repMax: 10, rest: 90, startWeight: 18),
            I(exerciseId: "seated_cable_row", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 40),
            I(exerciseId: "face_pull", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 15),
            I(exerciseId: "barbell_curl", sets: 3, repMin: 8, repMax: 10, rest: 75, startWeight: 20),
            I(exerciseId: "hammer_curl", sets: 2, repMin: 10, repMax: 12, rest: 60, startWeight: 10),
        ]),
        ProgramDayBlueprint(name: "Jour 5 · Jambes & tronc", focus: "Fessiers, quadriceps, abdominaux", symbol: "figure.core.training", items: [
            I(exerciseId: "hip_thrust", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 50),
            I(exerciseId: "walking_lunge", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 10),
            I(exerciseId: "leg_extension", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 30),
            I(exerciseId: "seated_leg_curl", sets: 3, repMin: 10, repMax: 12, rest: 60, startWeight: 25),
            I(exerciseId: "seated_calf_raise", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 20),
            I(exerciseId: "hanging_leg_raise", sets: 3, repMin: 10, repMax: 15, rest: 60, startWeight: 0),
        ]),
    ]

    static let fourDays: [ProgramDayBlueprint] = [
        ProgramDayBlueprint(name: "Jour 1 · Haut du corps A", focus: "Pectoraux, dos, bras", symbol: "figure.strengthtraining.traditional", items: [
            I(exerciseId: "bench_press", sets: 3, repMin: 6, repMax: 8, rest: 150, startWeight: 40),
            I(exerciseId: "barbell_row", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 35),
            I(exerciseId: "db_shoulder_press", sets: 3, repMin: 8, repMax: 10, rest: 90, startWeight: 12),
            I(exerciseId: "lat_pulldown", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 40),
            I(exerciseId: "db_curl", sets: 2, repMin: 10, repMax: 12, rest: 60, startWeight: 8),
            I(exerciseId: "triceps_pushdown", sets: 2, repMin: 10, repMax: 12, rest: 60, startWeight: 20),
        ]),
        ProgramDayBlueprint(name: "Jour 2 · Bas du corps A", focus: "Quadriceps, ischios", symbol: "figure.strengthtraining.functional", items: [
            I(exerciseId: "back_squat", sets: 3, repMin: 6, repMax: 8, rest: 150, startWeight: 50),
            I(exerciseId: "romanian_deadlift", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 45),
            I(exerciseId: "leg_press", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 80),
            I(exerciseId: "standing_calf_raise", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 40),
            I(exerciseId: "cable_crunch", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 20),
        ]),
        ProgramDayBlueprint(name: "Jour 3 · Haut du corps B", focus: "Épaules, dos, pectoraux", symbol: "figure.rower", items: [
            I(exerciseId: "overhead_press", sets: 3, repMin: 6, repMax: 8, rest: 150, startWeight: 25),
            I(exerciseId: "assisted_pullup", sets: 3, repMin: 6, repMax: 10, rest: 120, startWeight: 0),
            I(exerciseId: "incline_db_press", sets: 3, repMin: 8, repMax: 10, rest: 90, startWeight: 16),
            I(exerciseId: "seated_cable_row", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 40),
            I(exerciseId: "lateral_raise", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 6),
            I(exerciseId: "hammer_curl", sets: 2, repMin: 10, repMax: 12, rest: 60, startWeight: 10),
        ]),
        ProgramDayBlueprint(name: "Jour 4 · Bas du corps B", focus: "Fessiers, ischios, abdominaux", symbol: "figure.core.training", items: [
            I(exerciseId: "hip_thrust", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 50),
            I(exerciseId: "walking_lunge", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 10),
            I(exerciseId: "leg_curl", sets: 3, repMin: 10, repMax: 12, rest: 75, startWeight: 25),
            I(exerciseId: "leg_extension", sets: 3, repMin: 12, repMax: 15, rest: 60, startWeight: 30),
            I(exerciseId: "hanging_leg_raise", sets: 3, repMin: 10, repMax: 15, rest: 60, startWeight: 0),
        ]),
    ]

    static let threeDays: [ProgramDayBlueprint] = [
        ProgramDayBlueprint(name: "Jour 1 · Full body A", focus: "Corps complet", symbol: "figure.strengthtraining.traditional", items: [
            I(exerciseId: "back_squat", sets: 3, repMin: 6, repMax: 8, rest: 150, startWeight: 50),
            I(exerciseId: "bench_press", sets: 3, repMin: 6, repMax: 8, rest: 150, startWeight: 40),
            I(exerciseId: "barbell_row", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 35),
            I(exerciseId: "lateral_raise", sets: 2, repMin: 12, repMax: 15, rest: 60, startWeight: 6),
            I(exerciseId: "cable_crunch", sets: 2, repMin: 12, repMax: 15, rest: 60, startWeight: 20),
        ]),
        ProgramDayBlueprint(name: "Jour 2 · Full body B", focus: "Corps complet", symbol: "figure.strengthtraining.functional", items: [
            I(exerciseId: "romanian_deadlift", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 45),
            I(exerciseId: "overhead_press", sets: 3, repMin: 6, repMax: 8, rest: 150, startWeight: 25),
            I(exerciseId: "lat_pulldown", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 40),
            I(exerciseId: "leg_press", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 80),
            I(exerciseId: "db_curl", sets: 2, repMin: 10, repMax: 12, rest: 60, startWeight: 8),
        ]),
        ProgramDayBlueprint(name: "Jour 3 · Full body C", focus: "Corps complet", symbol: "figure.core.training", items: [
            I(exerciseId: "hip_thrust", sets: 3, repMin: 8, repMax: 10, rest: 120, startWeight: 50),
            I(exerciseId: "incline_db_press", sets: 3, repMin: 8, repMax: 10, rest: 90, startWeight: 16),
            I(exerciseId: "seated_cable_row", sets: 3, repMin: 10, repMax: 12, rest: 90, startWeight: 40),
            I(exerciseId: "walking_lunge", sets: 2, repMin: 10, repMax: 12, rest: 90, startWeight: 10),
            I(exerciseId: "triceps_pushdown", sets: 2, repMin: 10, repMax: 12, rest: 60, startWeight: 20),
        ]),
    ]
}
