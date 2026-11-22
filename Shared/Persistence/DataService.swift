import Foundation
import SwiftData

/// Data operations shared by the iPhone and the Apple Watch.
/// Every mutating operation saves immediately so nothing is lost if the app is terminated.
@MainActor
struct DataService {
    let context: ModelContext

    init(_ context: ModelContext) {
        self.context = context
    }

    func save() {
        do {
            if context.hasChanges { try context.save() }
        } catch {
            ErrorReporter.shared.report(error, message: "Impossible d'enregistrer les données.")
        }
    }

    // MARK: Profile

    func profile() -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func ensureProfile() -> UserProfile {
        if let existing = profile() { return existing }
        let profile = UserProfile()
        context.insert(profile)
        save()
        return profile
    }

    // MARK: Weight

    func weightEntries() -> [WeightEntry] {
        (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)]))) ?? []
    }

    /// Records a weight, keeping one entry per day, and updates the profile's current weight.
    @discardableResult
    func logWeight(_ kg: Double, on date: Date = .now) -> WeightEntry {
        let cal = Calendar.fitTrack
        let entry: WeightEntry
        if let sameDay = weightEntries().first(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            sameDay.weightKg = kg
            sameDay.date = date
            sameDay.savedToHealth = false
            entry = sameDay
        } else {
            entry = WeightEntry(date: date, weightKg: kg)
            context.insert(entry)
        }
        save()
        if let profile = profile(), weightEntries().last?.uuid == entry.uuid {
            profile.weightKg = kg
            profile.updatedAt = .now
            save()
        }
        return entry
    }

    // MARK: Program

    func templates() -> [WorkoutTemplate] {
        (try? context.fetch(FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.dayIndex)]))) ?? []
    }

    func seedProgramIfNeeded(sessionsPerWeek: Int) {
        guard templates().isEmpty else { return }
        installProgram(ProgramCatalog.program(sessionsPerWeek: sessionsPerWeek))
    }

    func replaceProgram(sessionsPerWeek: Int) {
        templates().forEach { context.delete($0) }
        installProgram(ProgramCatalog.program(sessionsPerWeek: sessionsPerWeek))
    }

    private func installProgram(_ days: [ProgramDayBlueprint]) {
        for (index, day) in days.enumerated() {
            let template = WorkoutTemplate(name: day.name, focus: day.focus, dayIndex: index, symbol: day.symbol)
            context.insert(template)
            for (order, item) in day.items.enumerated() {
                let ex = TemplateExercise(exerciseId: item.exerciseId, order: order, targetSets: item.sets,
                                          repMin: item.repMin, repMax: item.repMax, restSeconds: item.rest,
                                          startWeightKg: item.startWeight)
                context.insert(ex)
                ex.template = template
            }
        }
        save()
    }

    /// Replaces the local program with the one received from the iPhone (used on the Watch).
    func applyProgram(_ dto: ProgramDTO) {
        let existing = templates()
        let incomingIDs = Set(dto.templates.map(\.uuid))
        for template in existing where !incomingIDs.contains(template.uuid) {
            context.delete(template)
        }
        for t in dto.templates {
            let template = existing.first(where: { $0.uuid == t.uuid }) ?? {
                let created = WorkoutTemplate(name: t.name, focus: t.focus, dayIndex: t.dayIndex, symbol: t.symbol)
                created.uuid = t.uuid
                context.insert(created)
                return created
            }()
            template.name = t.name
            template.focus = t.focus
            template.dayIndex = t.dayIndex
            template.symbol = t.symbol
            template.updatedAt = .now
            (template.exercises ?? []).forEach { context.delete($0) }
            template.exercises = []
            for e in t.exercises {
                let ex = TemplateExercise(exerciseId: e.exerciseId, order: e.order, targetSets: e.targetSets,
                                          repMin: e.repMin, repMax: e.repMax, restSeconds: e.restSeconds,
                                          startWeightKg: e.startWeightKg)
                context.insert(ex)
                ex.template = template
            }
        }
        save()
    }

    /// Suggested next weight for the template exercise in the user's next session.
    func suggestion(for item: TemplateExercise, phoneSuggestions: [String: WeightSuggestionDTO] = [:]) -> ProgressionSuggestion {
        let exercise = item.exercise
        let last = lastSessionSamples(exerciseId: item.exerciseId)
        let local = StrengthMath.suggestion(previousSets: last.samples, repMin: item.repMin, repMax: item.repMax,
                                            isCompound: exercise?.isCompound ?? false,
                                            isLowerBody: exercise?.isLowerBody ?? false,
                                            fallbackWeight: item.startWeightKg)
        if let remote = phoneSuggestions[item.exerciseId] {
            let remoteDate = remote.basedOn ?? .distantPast
            if last.date == nil || remoteDate > (last.date ?? .distantPast) {
                return ProgressionSuggestion(weightKg: remote.weightKg, reps: remote.reps, kind: .addReps)
            }
        }
        return local
    }

    // MARK: Sessions

    func finishedSessions() -> [WorkoutSession] {
        let finished = WorkoutState.finished.rawValue
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw == finished },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func unfinishedSession() -> WorkoutSession? {
        let finished = WorkoutState.finished.rawValue
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw != finished },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Completed sets of the most recent finished session containing this exercise.
    func lastSessionSamples(exerciseId: String) -> (samples: [SetSample], date: Date?) {
        for session in finishedSessions() {
            let logs = session.orderedExercises.filter { $0.exerciseId == exerciseId }
            let sets = logs.flatMap(\.orderedSets).filter(\.isCompleted)
            if !sets.isEmpty {
                return (sets.map { SetSample(date: $0.completedAt ?? session.startDate, weightKg: $0.weightKg, reps: $0.reps) },
                        session.startDate)
            }
        }
        return ([], nil)
    }

    /// Every completed set ever recorded for an exercise (oldest first).
    func allSamples(exerciseId: String) -> [SetSample] {
        finishedSessions().reversed().flatMap { session in
            session.orderedExercises.filter { $0.exerciseId == exerciseId }
                .flatMap(\.orderedSets).filter(\.isCompleted)
                .map { SetSample(date: $0.completedAt ?? session.startDate, weightKg: $0.weightKg, reps: $0.reps) }
        }
    }

    /// Creates and persists a new session from a template, pre-filled with progression suggestions.
    @discardableResult
    func startSession(template: WorkoutTemplate?, device: WorkoutDevice,
                      phoneSuggestions: [String: WeightSuggestionDTO] = [:]) -> WorkoutSession {
        let session = WorkoutSession(name: template?.name ?? "Séance libre", templateUUID: template?.uuid, device: device)
        context.insert(session)
        for item in template?.orderedExercises ?? [] {
            let s = suggestion(for: item, phoneSuggestions: phoneSuggestions)
            let log = ExerciseLog(exerciseId: item.exerciseId, order: item.order, restSeconds: item.restSeconds,
                                  repMin: item.repMin, repMax: item.repMax)
            context.insert(log)
            log.session = session
            for i in 0..<max(1, item.targetSets) {
                let set = SetLog(order: i, reps: s.reps, weightKg: s.weightKg)
                context.insert(set)
                set.exerciseLog = log
            }
        }
        save()
        return session
    }

    @discardableResult
    func addExercise(_ exerciseId: String, to session: WorkoutSession, sets: Int = 3) -> ExerciseLog {
        let nextOrder = (session.orderedExercises.last?.order ?? -1) + 1
        let last = lastSessionSamples(exerciseId: exerciseId).samples.last
        let log = ExerciseLog(exerciseId: exerciseId, order: nextOrder, restSeconds: 90, repMin: 8, repMax: 12)
        context.insert(log)
        log.session = session
        for i in 0..<sets {
            let set = SetLog(order: i, reps: last?.reps ?? 10, weightKg: last?.weightKg ?? 0)
            context.insert(set)
            set.exerciseLog = log
        }
        save()
        return log
    }

    func removeExercise(_ log: ExerciseLog) {
        context.delete(log)
        save()
    }

    @discardableResult
    func addSet(to log: ExerciseLog) -> SetLog {
        let previous = log.orderedSets.last
        let set = SetLog(order: (previous?.order ?? -1) + 1, reps: previous?.reps ?? 10, weightKg: previous?.weightKg ?? 0)
        context.insert(set)
        set.exerciseLog = log
        save()
        return set
    }

    func removeSet(_ set: SetLog) {
        context.delete(set)
        save()
    }

    func completeSet(_ set: SetLog, completed: Bool = true) {
        set.isCompleted = completed
        set.completedAt = completed ? .now : nil
        // Propagate the weight/reps to the following not-yet-completed sets of the same exercise.
        if completed, let log = set.exerciseLog {
            for next in log.orderedSets where next.order > set.order && !next.isCompleted {
                next.weightKg = set.weightKg
            }
        }
        save()
    }

    func discard(_ session: WorkoutSession) {
        context.delete(session)
        save()
    }

    /// Imports a session received from the Watch. Idempotent: a session already present is ignored.
    @discardableResult
    func importSession(_ dto: SessionDTO) -> Bool {
        let id = dto.uuid
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.uuid == id })
        if let count = try? context.fetchCount(descriptor), count > 0 { return false }
        let session = WorkoutSession(name: dto.name, templateUUID: dto.templateUUID,
                                     device: WorkoutDevice(rawValue: dto.device) ?? .watch, startDate: dto.startDate)
        session.uuid = dto.uuid
        session.endDate = dto.endDate ?? dto.startDate
        session.pausedSeconds = dto.pausedSeconds
        session.activeEnergyKcal = dto.activeEnergyKcal
        session.averageHeartRate = dto.averageHeartRate
        session.savedToHealth = dto.savedToHealth
        session.syncedToPhone = true
        session.state = .finished
        context.insert(session)
        for e in dto.exercises {
            let log = ExerciseLog(exerciseId: e.exerciseId, order: e.order, restSeconds: e.restSeconds, repMin: e.repMin, repMax: e.repMax)
            log.uuid = e.uuid
            context.insert(log)
            log.session = session
            for s in e.sets {
                let set = SetLog(order: s.order, reps: s.reps, weightKg: s.weightKg)
                set.uuid = s.uuid
                set.isCompleted = s.isCompleted
                set.completedAt = s.completedAt
                context.insert(set)
                set.exerciseLog = log
            }
        }
        save()
        return true
    }

    // MARK: Nutrition

    func foodEntries(on day: Date) -> [FoodEntry] {
        let cal = Calendar.fitTrack
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.date >= start && $0.date < end },
                                                    sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func addFood(_ food: FoodItem, grams: Double, meal: MealType, day: Date) -> FoodEntry {
        let cal = Calendar.fitTrack
        // Keep the chosen day but use the current time of day so entries sort naturally.
        let time = cal.dateComponents([.hour, .minute, .second], from: .now)
        let date = cal.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? day
        let entry = FoodEntry(food: food, quantityGrams: grams, meal: meal, date: date)
        context.insert(entry)
        save()
        return entry
    }

    /// Distinct recently logged foods (most recent first).
    func recentFoods(limit: Int = 20) -> [FoodItem] {
        var descriptor = FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 200
        var seen = Set<String>()
        var result: [FoodItem] = []
        for entry in (try? context.fetch(descriptor)) ?? [] {
            let key = entry.barcode.isEmpty ? "\(entry.name)|\(entry.brand)" : entry.barcode
            if seen.insert(key).inserted { result.append(entry.asFoodItem) }
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: Maintenance

    /// Removes duplicated records (same `uuid`), which can appear after iCloud merges.
    func removeDuplicates() {
        func dedupe<T: PersistentModel>(_ type: T.Type, uuid: (T) -> UUID, newest: (T, T) -> Bool) {
            let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
            let groups = Dictionary(grouping: all, by: uuid)
            for (_, items) in groups where items.count > 1 {
                let sorted = items.sorted(by: newest)
                sorted.dropFirst().forEach { context.delete($0) }
            }
        }
        dedupe(UserProfile.self, uuid: { $0.uuid }, newest: { $0.updatedAt > $1.updatedAt })
        dedupe(WeightEntry.self, uuid: { $0.uuid }, newest: { $0.date > $1.date })
        dedupe(WorkoutTemplate.self, uuid: { $0.uuid }, newest: { $0.updatedAt > $1.updatedAt })
        dedupe(WorkoutSession.self, uuid: { $0.uuid }, newest: { ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast) })
        dedupe(FoodEntry.self, uuid: { $0.uuid }, newest: { $0.createdAt > $1.createdAt })
        // Several profiles may exist if two devices were set up before iCloud merged: keep the most recently edited.
        let profiles = ((try? context.fetch(FetchDescriptor<UserProfile>())) ?? []).sorted { $0.updatedAt > $1.updatedAt }
        profiles.dropFirst().forEach { context.delete($0) }
        save()
    }

    func deleteAllData() {
        do {
            try context.delete(model: FoodEntry.self)
            try context.delete(model: SetLog.self)
            try context.delete(model: ExerciseLog.self)
            try context.delete(model: WorkoutSession.self)
            try context.delete(model: TemplateExercise.self)
            try context.delete(model: WorkoutTemplate.self)
            try context.delete(model: WeightEntry.self)
            try context.delete(model: UserProfile.self)
            try context.save()
        } catch {
            ErrorReporter.shared.report(error, message: "La suppression des données a échoué.")
        }
    }
}
