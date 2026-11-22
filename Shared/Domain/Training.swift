import Foundation

/// Wall-clock based workout timing that survives app suspension and termination.
struct WorkoutTiming: Equatable {
    var startDate: Date
    var endDate: Date?
    var pausedSeconds: Double
    var pauseStartedAt: Date?

    func elapsed(at date: Date = .now) -> TimeInterval {
        let end = endDate ?? pauseStartedAt ?? date
        return max(0, end.timeIntervalSince(startDate) - pausedSeconds)
    }
}

/// A completed set used for statistics.
struct SetSample: Equatable {
    var date: Date
    var weightKg: Double
    var reps: Int
}

struct PersonalRecord: Equatable, Identifiable {
    var id: String { exerciseId }
    var exerciseId: String
    var maxWeightKg: Double
    var maxWeightReps: Int
    var bestEstimatedOneRepMax: Double
    var date: Date
}

enum StrengthMath {
    /// Epley estimated one-repetition maximum.
    static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double {
        guard weightKg > 0, reps > 0 else { return 0 }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }

    static func personalRecord(exerciseId: String, samples: [SetSample]) -> PersonalRecord? {
        let valid = samples.filter { $0.reps > 0 }
        guard let heaviest = valid.max(by: { ($0.weightKg, $0.reps) < ($1.weightKg, $1.reps) }) else { return nil }
        let best = valid.map { estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0
        return PersonalRecord(exerciseId: exerciseId, maxWeightKg: heaviest.weightKg,
                              maxWeightReps: heaviest.reps, bestEstimatedOneRepMax: best, date: heaviest.date)
    }

    /// Weight increment for progressive overload.
    static func increment(isCompound: Bool, isLowerBody: Bool) -> Double {
        if isCompound { return isLowerBody ? 5 : 2.5 }
        return 1
    }

    /// Progressive overload rule (double progression):
    /// when every working set of the previous session reached the top of the rep range,
    /// the weight goes up; otherwise keep the weight and aim for more repetitions.
    static func suggestion(previousSets: [SetSample], repMin: Int, repMax: Int,
                           isCompound: Bool, isLowerBody: Bool, fallbackWeight: Double) -> ProgressionSuggestion {
        guard !previousSets.isEmpty else {
            return ProgressionSuggestion(weightKg: fallbackWeight, reps: repMin, kind: .firstTime)
        }
        let topWeight = previousSets.map(\.weightKg).max() ?? fallbackWeight
        let atTop = previousSets.filter { $0.weightKg >= topWeight }
        if !atTop.isEmpty && atTop.allSatisfy({ $0.reps >= repMax }) {
            let inc = increment(isCompound: isCompound, isLowerBody: isLowerBody)
            return ProgressionSuggestion(weightKg: topWeight + inc, reps: repMin, kind: .increaseWeight(by: inc))
        }
        let minReps = atTop.map(\.reps).min() ?? repMin
        return ProgressionSuggestion(weightKg: topWeight, reps: min(repMax, max(repMin, minReps + 1)), kind: .addReps)
    }
}

struct ProgressionSuggestion: Equatable {
    enum Kind: Equatable {
        case firstTime
        case increaseWeight(by: Double)
        case addReps
    }
    var weightKg: Double
    var reps: Int
    var kind: Kind

    var message: String {
        switch kind {
        case .firstTime:
            return "Première fois : choisissez une charge que vous pouvez soulever proprement."
        case .increaseWeight(let inc):
            return "Objectif atteint la dernière fois : +\(FTFormat.weight(inc)) aujourd'hui."
        case .addReps:
            return "Gardez la même charge et visez \(reps) répétitions."
        }
    }
}

/// Aggregated statistics over workout sessions.
enum TrainingStats {
    static func sessions(in interval: DateInterval, dates: [Date]) -> Int {
        dates.filter { interval.contains($0) }.count
    }

    /// Start of the week containing `date` (Monday-based, French convention).
    static func startOfWeek(for date: Date, calendar: Calendar = .fitTrack) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Number of sessions per week for the last `weeks` weeks (oldest first).
    static func weeklyCounts(dates: [Date], weeks: Int, now: Date = .now, calendar: Calendar = .fitTrack) -> [(weekStart: Date, count: Int)] {
        let current = startOfWeek(for: now, calendar: calendar)
        return (0..<weeks).reversed().map { offset in
            let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: current) ?? current
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return (start, dates.filter { $0 >= start && $0 < end }.count)
        }
    }

    /// Consecutive weeks (ending with the current or previous week) with at least one session.
    static func weekStreak(dates: [Date], now: Date = .now, calendar: Calendar = .fitTrack) -> Int {
        let counts = weeklyCounts(dates: dates, weeks: 104, now: now, calendar: calendar).map(\.count)
        var streak = 0
        var idx = counts.count - 1
        if counts.last == 0 { idx -= 1 } // current week not started yet does not break the streak
        while idx >= 0 && counts[idx] > 0 { streak += 1; idx -= 1 }
        return streak
    }
}

extension Calendar {
    /// Gregorian calendar with French conventions (weeks start on Monday).
    static var fitTrack: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "fr_FR")
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        cal.timeZone = .current
        return cal
    }
}
