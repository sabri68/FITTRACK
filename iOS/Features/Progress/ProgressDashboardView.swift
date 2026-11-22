import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    enum Period: String, CaseIterable, Identifiable {
        case month, quarter, year
        var id: String { rawValue }
        var label: String {
            switch self {
            case .month: return "4 semaines"
            case .quarter: return "3 mois"
            case .year: return "1 an"
            }
        }
        var weeks: Int {
            switch self {
            case .month: return 4
            case .quarter: return 13
            case .year: return 52
            }
        }
        var startDate: Date {
            let start = TrainingStats.startOfWeek(for: .now)
            return Calendar.fitTrack.date(byAdding: .weekOfYear, value: -(weeks - 1), to: start) ?? start
        }
    }

    @Environment(AppModel.self) private var model
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query(filter: #Predicate<WorkoutSession> { $0.stateRaw == "finished" }, sort: \WorkoutSession.startDate)
    private var sessions: [WorkoutSession]
    @Query(sort: \FoodEntry.date) private var foods: [FoodEntry]
    @State private var period: Period = .month
    @State private var selectedExercise: String?
    @State private var showWeightSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    Picker("Période", selection: $period) {
                        ForEach(Period.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("progress.period")

                    summaryTiles
                    weightSection
                    frequencySection
                    strengthSection
                    recordsSection
                    nutritionSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Theme.groupedBackground)
            .navigationTitle("Progrès")
            .sheet(isPresented: $showWeightSheet) {
                WeightEntrySheet(initial: profiles.first?.weightKg ?? 77)
                    .presentationDetents([.height(320)])
            }
        }
    }

    private var periodSessions: [WorkoutSession] { sessions.filter { $0.startDate >= period.startDate } }

    // MARK: Summary

    private var summaryTiles: some View {
        let list = periodSessions
        let avgDuration = list.isEmpty ? 0 : list.reduce(0) { $0 + $1.elapsed() } / Double(list.count)
        let perWeek = Double(list.count) / Double(period.weeks)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Séances", value: "\(list.count)", subtitle: "\(FTFormat.number(perWeek)) / semaine",
                     symbol: "dumbbell.fill")
            StatTile(title: "Volume total", value: "\(FTFormat.integer(list.reduce(0) { $0 + $1.totalVolume })) kg",
                     symbol: "scalemass.fill", tint: Theme.protein)
            StatTile(title: "Durée moyenne", value: FTFormat.durationLong(avgDuration), symbol: "clock.fill", tint: .teal)
            StatTile(title: "Série en cours", value: "\(TrainingStats.weekStreak(dates: sessions.map(\.startDate))) sem.",
                     subtitle: "Semaines consécutives", symbol: "flame.fill", tint: .orange)
        }
    }

    // MARK: Weight

    private var weightSection: some View {
        let points = weights.filter { $0.date >= period.startDate }
        let target = profiles.first?.targetWeightKg
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Poids").font(.headline)
                Spacer()
                Button("Ajouter") { showWeightSheet = true }.buttonStyle(SecondaryButtonStyle())
            }
            if points.count >= 2 {
                let first = points.first?.weightKg ?? 0, last = points.last?.weightKg ?? 0
                Text("\(last - first >= 0 ? "+" : "")\(FTFormat.number(last - first)) kg sur la période")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Chart {
                    ForEach(points) { w in
                        LineMark(x: .value("Date", w.date), y: .value("Poids", w.weightKg))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.accent)
                        PointMark(x: .value("Date", w.date), y: .value("Poids", w.weightKg))
                            .foregroundStyle(Theme.accent)
                            .symbolSize(24)
                    }
                    if let target {
                        RuleMark(y: .value("Objectif", target))
                            .foregroundStyle(Theme.positive)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Objectif \(FTFormat.weight(target))").font(.caption2).foregroundStyle(Theme.positive)
                            }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 190)
            } else {
                Text("Ajoutez au moins deux pesées pour voir l'évolution de votre poids.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: Frequency & volume

    private var frequencySection: some View {
        let counts = TrainingStats.weeklyCounts(dates: sessions.map(\.startDate), weeks: period.weeks)
        let goal = profiles.first?.sessionsPerWeek ?? 5
        let weekly: [ChartPoint] = counts.map { ChartPoint(date: $0.weekStart, value: Double($0.count)) }
        let volumes: [ChartPoint] = counts.map { week in
            let end = Calendar.fitTrack.date(byAdding: .weekOfYear, value: 1, to: week.weekStart) ?? week.weekStart
            return ChartPoint(date: week.weekStart, value: sessions.filter { $0.startDate >= week.weekStart && $0.startDate < end }
                .reduce(0) { $0 + $1.totalVolume })
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Fréquence d'entraînement").font(.headline)
            Chart {
                ForEach(weekly) { week in
                    BarMark(x: .value("Semaine", week.date, unit: .weekOfYear), y: .value("Séances", week.value))
                        .foregroundStyle(Int(week.value) >= goal ? AnyShapeStyle(Theme.positive) : AnyShapeStyle(Theme.accentGradient))
                        .cornerRadius(4)
                }
                RuleMark(y: .value("Objectif", goal))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 160)
            Text("Volume hebdomadaire (kg)").font(.subheadline.weight(.semibold)).padding(.top, 6)
            Chart {
                ForEach(volumes) { item in
                    AreaMark(x: .value("Semaine", item.date, unit: .weekOfYear), y: .value("Volume", item.value))
                        .foregroundStyle(Theme.protein.opacity(0.25))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Semaine", item.date, unit: .weekOfYear), y: .value("Volume", item.value))
                        .foregroundStyle(Theme.protein)
                        .interpolationMethod(.monotone)
                }
            }
            .frame(height: 120)
        }
        .cardStyle()
    }

    // MARK: Strength

    private var exercisesWithData: [String] {
        var counts: [String: Int] = [:]
        for s in sessions {
            for log in s.orderedExercises where log.orderedSets.contains(where: \.isCompleted) {
                counts[log.exerciseId, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    private var strengthSection: some View {
        let ids = exercisesWithData
        let current = selectedExercise ?? ids.first
        let points: [ProgressPoint] = current.map { id in
            sessions.compactMap { session in
                let sets = session.orderedExercises.filter { $0.exerciseId == id }.flatMap(\.orderedSets)
                    .filter { $0.isCompleted && $0.reps > 0 }
                guard !sets.isEmpty else { return nil }
                return ProgressPoint(date: session.startDate,
                                     oneRM: sets.map { StrengthMath.estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0,
                                     top: sets.map(\.weightKg).max() ?? 0)
            }
        } ?? []
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progression de force").font(.headline)
                Spacer()
                if !ids.isEmpty {
                    Menu {
                        ForEach(ids, id: \.self) { id in
                            Button(ExerciseCatalog.exercise(id: id)?.name ?? id) { selectedExercise = id }
                        }
                    } label: {
                        Label(current.flatMap { ExerciseCatalog.exercise(id: $0)?.name } ?? "Exercice",
                              systemImage: "chevron.up.chevron.down")
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            }
            if points.count >= 2 {
                Chart(points) { p in
                    LineMark(x: .value("Date", p.date), y: .value("1RM estimé", p.oneRM))
                        .foregroundStyle(Theme.accent)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", p.date), y: .value("1RM estimé", p.oneRM))
                        .foregroundStyle(Theme.accent)
                    LineMark(x: .value("Date", p.date), y: .value("Charge max", p.top), series: .value("Série", "max"))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
                Text("Trait plein : 1RM estimé (Epley) · pointillés : charge maximale").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Réalisez au moins deux séances avec un exercice pour suivre sa progression.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: Records

    private var recordsSection: some View {
        let records: [PersonalRecord] = exercisesWithData.compactMap { id in
            StrengthMath.personalRecord(exerciseId: id, samples: model.data.allSamples(exerciseId: id))
        }.sorted { $0.bestEstimatedOneRepMax > $1.bestEstimatedOneRepMax }
        return VStack(alignment: .leading, spacing: 10) {
            Label("Records personnels", systemImage: "trophy.fill").font(.headline).foregroundStyle(.primary)
            if records.isEmpty {
                Text("Vos records apparaîtront après vos premières séances.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(records.prefix(8)) { record in
                if let exercise = ExerciseCatalog.exercise(id: record.exerciseId) {
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name).font(.subheadline.weight(.semibold))
                                Text(FTFormat.dayMedium(record.date)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(FTFormat.weight(record.maxWeightKg)) × \(record.maxWeightReps)")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                Text("1RM ≈ \(FTFormat.weight(record.bestEstimatedOneRepMax))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    // MARK: Nutrition

    private var nutritionSection: some View {
        let cal = Calendar.fitTrack
        let inPeriod = foods.filter { $0.date >= period.startDate }
        let byDay = Dictionary(grouping: inPeriod) { cal.startOfDay(for: $0.date) }
        let daily: [DayMacros] = byDay.map { DayMacros(date: $0.key, macros: $0.value.map(\.macros).total) }
            .sorted { $0.date < $1.date }
        let average = daily.map(\.macros).total / Double(max(1, daily.count))
        let targets = profiles.first?.targets
        return VStack(alignment: .leading, spacing: 10) {
            Text("Nutrition").font(.headline)
            if daily.isEmpty {
                Text("Enregistrez vos repas pour voir vos moyennes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Moyennes sur \(daily.count) jour\(daily.count > 1 ? "s" : "") renseigné\(daily.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    averageTile("Calories", FTFormat.integer(average.kcal), targets.map { FTFormat.integer($0.calories) }, Theme.accent)
                    averageTile("Protéines", FTFormat.integer(average.protein), targets.map { FTFormat.integer($0.protein) }, Theme.protein)
                    averageTile("Glucides", FTFormat.integer(average.carbs), targets.map { FTFormat.integer($0.carbs) }, Theme.carbs)
                    averageTile("Lipides", FTFormat.integer(average.fat), targets.map { FTFormat.integer($0.fat) }, Theme.fat)
                }
                Chart {
                    ForEach(daily) { day in
                        BarMark(x: .value("Jour", day.date, unit: .day), y: .value("kcal", day.macros.kcal))
                            .foregroundStyle(Theme.accentGradient)
                            .cornerRadius(3)
                    }
                    if let targets {
                        RuleMark(y: .value("Objectif", targets.calories))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .frame(height: 150)
            }
        }
        .cardStyle()
    }

    private func averageTile(_ title: String, _ value: String, _ target: String?, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(color)
            if let target { Text("/ \(target)").font(.caption2).foregroundStyle(.secondary) }
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChartPoint: Identifiable {
    var id: Date { date }
    var date: Date
    var value: Double
}

struct DayMacros: Identifiable {
    var id: Date { date }
    var date: Date
    var macros: Macros
}
