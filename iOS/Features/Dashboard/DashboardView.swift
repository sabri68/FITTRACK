import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(HealthKitService.self) private var health
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \WorkoutTemplate.dayIndex) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var todayFood: [FoodEntry]
    @State private var showWeightSheet = false

    init() {
        let cal = Calendar.fitTrack
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        _todayFood = Query(filter: #Predicate<FoodEntry> { $0.date >= start && $0.date < end })
    }

    private var profile: UserProfile? { profiles.first }
    private var finished: [WorkoutSession] { sessions.filter { $0.state == .finished } }
    private var unfinished: WorkoutSession? { sessions.first { $0.state != .finished } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    header
                    if let unfinished { resumeBanner(unfinished) }
                    if let profile { caloriesCard(profile) }
                    nextWorkoutCard
                    SectionHeader(title: "Aujourd'hui")
                    activityGrid
                    SectionHeader(title: "Cette semaine")
                    weeklyCard
                    if let profile { weightCard(profile) }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Theme.groupedBackground)
            .navigationTitle("Accueil")
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await health.refreshToday() }
            .sheet(isPresented: $showWeightSheet) {
                WeightEntrySheet(initial: profile?.weightKg ?? 77)
                    .presentationDetents([.height(320)])
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(FTFormat.dayLong(.now).capitalized(with: FTFormat.locale))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(greeting).font(.largeTitle.weight(.bold))
        }
        .padding(.top, 12)
    }

    private var greeting: String {
        let hour = Calendar.fitTrack.component(.hour, from: .now)
        let base = hour < 18 ? "Bonjour" : "Bonsoir"
        if let name = profile?.firstName, !name.isEmpty { return "\(base), \(name)" }
        return base
    }

    private func resumeBanner(_ session: WorkoutSession) -> some View {
        Button {
            model.presentedSession = session
        } label: {
            HStack(spacing: 12) {
                Image(systemName: session.state == .paused ? "pause.circle.fill" : "record.circle")
                    .font(.title2)
                    .symbolEffect(.pulse, options: .repeating)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.state == .paused ? "Séance en pause" : "Séance en cours").font(.headline)
                    Text(session.name).font(.subheadline).opacity(0.9)
                }
                Spacer()
                Text("Reprendre").font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding()
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.accentGradient))
        }
        .accessibilityIdentifier("dashboard.resume")
    }

    private func caloriesCard(_ profile: UserProfile) -> some View {
        let targets = profile.targets
        let eaten = todayFood.map(\.macros).total
        let remaining = targets.calories - eaten.kcal
        return Button {
            model.selectedTab = .nutrition
        } label: {
            VStack(spacing: 18) {
                HStack(spacing: 22) {
                    ZStack {
                        RingView(progress: targets.calories > 0 ? eaten.kcal / targets.calories : 0, lineWidth: 16)
                        VStack(spacing: 0) {
                            Text(FTFormat.integer(abs(remaining)))
                                .font(.title.weight(.bold).monospacedDigit())
                                .contentTransition(.numericText())
                            Text(remaining >= 0 ? "kcal restantes" : "kcal en trop")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 140, height: 140)
                    VStack(alignment: .leading, spacing: 12) {
                        calorieLine("Objectif", targets.calories, "target")
                        calorieLine("Consommées", eaten.kcal, "fork.knife")
                        if let active = health.todayActiveEnergy {
                            calorieLine("Dépensées (actif)", active, "flame.fill")
                        }
                    }
                }
                VStack(spacing: 12) {
                    MacroBar(title: "Protéines", value: eaten.protein, target: targets.protein, color: Theme.protein)
                    MacroBar(title: "Glucides", value: eaten.carbs, target: targets.carbs, color: Theme.carbs)
                    MacroBar(title: "Lipides", value: eaten.fat, target: targets.fat, color: Theme.fat)
                }
            }
            .foregroundStyle(.primary)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard.calories")
    }

    private func calorieLine(_ title: String, _ value: Double, _ symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(FTFormat.kcal(value)).font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
    }

    private var nextTemplate: WorkoutTemplate? {
        guard !templates.isEmpty else { return nil }
        guard let lastTemplateID = finished.first(where: { $0.templateUUID != nil })?.templateUUID,
              let index = templates.firstIndex(where: { $0.uuid == lastTemplateID }) else {
            return templates.first
        }
        return templates[(index + 1) % templates.count]
    }

    @ViewBuilder
    private var nextWorkoutCard: some View {
        if let next = nextTemplate {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Prochaine séance", systemImage: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(next.orderedExercises.count) exercices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    Image(systemName: next.symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accentGradient))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next.name).font(.headline)
                        Text(next.focus).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Button {
                    model.startWorkout(template: next)
                } label: {
                    Label(unfinished == nil ? "Démarrer la séance" : "Reprendre la séance en cours", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("dashboard.startWorkout")
            }
            .cardStyle()
        }
    }

    private var activityGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatTile(title: "Pas", value: health.todaySteps.map { FTFormat.integer($0) } ?? "–",
                     subtitle: healthSubtitle, symbol: "figure.walk", tint: .green)
            StatTile(title: "Énergie active", value: health.todayActiveEnergy.map { FTFormat.kcal($0) } ?? "–",
                     subtitle: healthSubtitle, symbol: "flame.fill", tint: .orange)
            StatTile(title: "Minutes d'exercice", value: health.todayExerciseMinutes.map { "\(FTFormat.integer($0)) min" } ?? "–",
                     subtitle: healthSubtitle, symbol: "stopwatch.fill", tint: .teal)
            StatTile(title: "Séances aujourd'hui", value: "\(finished.filter { Calendar.fitTrack.isDateInToday($0.startDate) }.count)",
                     subtitle: nil, symbol: "dumbbell.fill", tint: Theme.accent)
        }
    }

    private var healthSubtitle: String? {
        switch health.status {
        case .unavailable: return "Santé indisponible"
        case .notDetermined: return "Santé non connecté"
        case .denied: return "Accès Santé refusé"
        default: return nil
        }
    }

    private var weeklyCard: some View {
        let weekStart = TrainingStats.startOfWeek(for: .now)
        let thisWeek = finished.filter { $0.startDate >= weekStart }
        let goal = max(1, profile?.sessionsPerWeek ?? 5)
        let volume = thisWeek.reduce(0) { $0 + $1.totalVolume }
        let duration = thisWeek.reduce(0) { $0 + $1.elapsed() }
        let streak = TrainingStats.weekStreak(dates: finished.map(\.startDate))
        let days = (0..<7).compactMap { Calendar.fitTrack.date(byAdding: .day, value: $0, to: weekStart) }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(thisWeek.count)").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("/ \(goal) séances").font(.headline).foregroundStyle(.secondary)
                Spacer()
                if streak > 1 {
                    Label("\(streak) semaines", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            ProgressView(value: min(Double(thisWeek.count), Double(goal)), total: Double(goal))
                .tint(Theme.accent)
            HStack {
                ForEach(days, id: \.self) { day in
                    let trained = thisWeek.contains { Calendar.fitTrack.isDate($0.startDate, inSameDayAs: day) }
                    VStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.narrow).locale(FTFormat.locale)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(trained ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.subtleFill))
                            .frame(width: 26, height: 26)
                            .overlay {
                                if trained { Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(.white) }
                            }
                            .overlay {
                                if Calendar.fitTrack.isDateInToday(day) { Circle().stroke(Theme.accent, lineWidth: 2) }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack {
                Label(FTFormat.durationLong(duration), systemImage: "clock")
                Spacer()
                Label("\(FTFormat.integer(volume)) kg soulevés", systemImage: "scalemass")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private func weightCard(_ profile: UserProfile) -> some View {
        let start = weights.first?.weightKg ?? profile.weightKg
        let current = profile.weightKg
        let target = profile.targetWeightKg
        let totalChange = target - start
        let progress = abs(totalChange) < 0.05 ? 1 : max(0, min(1, (current - start) / totalChange))
        let delta = current - start
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Poids").font(.headline)
                Spacer()
                Button("Ajouter") { showWeightSheet = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("dashboard.addWeight")
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(FTFormat.number(current)).font(.system(size: 34, weight: .bold, design: .rounded))
                Text("kg").font(.headline).foregroundStyle(.secondary)
                Spacer()
                if weights.count > 1 {
                    Label("\(delta > 0 ? "+" : "")\(FTFormat.number(delta)) kg",
                          systemImage: delta <= 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: progress).tint(Theme.positive)
            HStack {
                Text("Départ : \(FTFormat.weight(start))")
                Spacer()
                Text("Objectif : \(FTFormat.weight(target))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

/// Sheet used to record a body weight measurement.
struct WeightEntrySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double
    @State private var date = Date()

    init(initial: Double) {
        _weight = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Text("Poids")
                    Spacer()
                    DecimalField(title: "Poids", value: $weight, suffix: "kg", width: 90)
                        .font(.title2.weight(.semibold))
                }
                Stepper("Ajuster de 0,1 kg", value: $weight, in: 30...300, step: 0.1)
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            }
            .navigationTitle("Nouvelle pesée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        model.logWeight(weight, date: date)
                        dismiss()
                    }
                    .disabled(!(30...300).contains(weight))
                    .accessibilityIdentifier("weight.save")
                }
            }
        }
    }
}
