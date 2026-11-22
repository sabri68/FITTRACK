import Foundation

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var label: String {
        switch self {
        case .male: return "Homme"
        case .female: return "Femme"
        }
    }
}

enum FitnessLevel: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var label: String {
        switch self {
        case .beginner: return "Débutant"
        case .intermediate: return "Intermédiaire"
        case .advanced: return "Avancé"
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case recomposition, buildMuscle, loseFat, maintain
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recomposition: return "Prendre du muscle et perdre du gras"
        case .buildMuscle: return "Prendre du muscle"
        case .loseFat: return "Perdre du gras"
        case .maintain: return "Maintenir ma forme"
        }
    }
    var shortLabel: String {
        switch self {
        case .recomposition: return "Recomposition"
        case .buildMuscle: return "Prise de muscle"
        case .loseFat: return "Perte de gras"
        case .maintain: return "Maintien"
        }
    }
    /// Multiplier applied to maintenance calories.
    var calorieFactor: Double {
        switch self {
        case .recomposition: return 0.90
        case .buildMuscle: return 1.10
        case .loseFat: return 0.80
        case .maintain: return 1.0
        }
    }
    /// Protein target in g per kg of body weight.
    var proteinPerKg: Double {
        switch self {
        case .recomposition, .loseFat: return 2.0
        case .buildMuscle: return 1.8
        case .maintain: return 1.6
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, high, veryHigh
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sedentary: return "Sédentaire"
        case .light: return "Légère (1–2 séances)"
        case .moderate: return "Modérée (3–4 séances)"
        case .high: return "Élevée (5–6 séances)"
        case .veryHigh: return "Très élevée (travail physique)"
        }
    }
    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.465
        case .high: return 1.55
        case .veryHigh: return 1.725
        }
    }
    static func from(sessionsPerWeek: Int) -> ActivityLevel {
        switch sessionsPerWeek {
        case ..<1: return .sedentary
        case 1...2: return .light
        case 3...4: return .moderate
        default: return .high
        }
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var label: String {
        switch self {
        case .breakfast: return "Petit-déjeuner"
        case .lunch: return "Déjeuner"
        case .dinner: return "Dîner"
        case .snack: return "Collations"
        }
    }
    var symbol: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "takeoutbag.and.cup.and.straw.fill"
        }
    }
    /// Suggested meal based on the hour of the day.
    static func suggested(for date: Date = .now, calendar: Calendar = .current) -> MealType {
        switch calendar.component(.hour, from: date) {
        case 4..<11: return .breakfast
        case 11..<15: return .lunch
        case 18..<23: return .dinner
        default: return .snack
        }
    }
}

enum FoodSource: String, Codable, CaseIterable {
    case generic, openFoodFacts, barcode, photo, manual
    var label: String {
        switch self {
        case .generic: return "Base FitTrack"
        case .openFoodFacts: return "Open Food Facts"
        case .barcode: return "Code-barres"
        case .photo: return "Photo"
        case .manual: return "Saisie manuelle"
        }
    }
}

enum WorkoutState: String, Codable {
    case active, paused, finished
}

enum WorkoutDevice: String, Codable {
    case iPhone, watch
    var label: String {
        switch self {
        case .iPhone: return "iPhone"
        case .watch: return "Apple Watch"
        }
    }
}
