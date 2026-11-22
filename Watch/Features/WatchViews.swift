import SwiftUI
import SwiftData
import WatchKit

enum WatchTheme {
    static let accent = Color("AccentColor")
    static let gradient = LinearGradient(colors: [Color(red: 1.0, green: 0.42, blue: 0.24), Color(red: 0.91, green: 0.12, blue: 0.39)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let positive = Color(red: 0.2, green: 0.8, blue: 0.5)
}

// MARK: - Home

struct WatchRootView: View {
    @Environment(WatchAppModel.self) private var model
    @Environment(WatchSyncService.self) private var sync
    @Environment(WatchWorkoutManager.self) private var workout
    @Query(sort: \WorkoutTemplate.dayIndex) private var templates: [WorkoutTemplate]
    @Query(filter: #Predicate<WorkoutSession> { $0.stateRaw == "finished" }, sort: \WorkoutSession.startDate, order: .reverse)
    private var finished: [WorkoutSession]

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                if let active = model.activeSession {
                    Button {
                        model.activeSession = active
                    } label: {
                        Label("Reprendre la séance", systemImage: "play.circle.fill")
                    }
                    .listItemTint(WatchTheme.accent)
                }
                Section("Programme") {
                    ForEach(templates) { template in
                        NavigationLink(value: template) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name).font(.headline).lineLimit(2)
                                Text("\(template.orderedExercises.count) exercices")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("watch.template.\(template.dayIndex)")
                    }
                }
                Section("Historique") {
                    if finished.isEmpty {
                        Text("Aucune séance").foregroundStyle(.secondary)
                    }
                    ForEach(finished.prefix(3)) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.footnote.weight(.semibold)).lineLimit(1)
                            Text("\(FTFormat.dayShort(s.startDate)) · \(FTFormat.durationLong(s.elapsed()))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Label(sync.statusLabel, systemImage: sync.isReachable ? "iphone" : "iphone.slash")
                        .font(.footnote)
                    Label(workout.healthState.label, systemImage: "heart.fill")
                        .font(.footnote)
                }
            }
            .navigationTitle("FitTrack")
            .navigationDestination(for: WorkoutTemplate.self) { WatchTemplateView(template: $0) }
        }
        .fullScreenCover(item: $model.activeSession) { session in
            WatchActiveWorkoutView(session: session)
        }
        .sheet(item: $model.lastSummary) { summary in
            WatchSummaryView(summary: summary)
        }
    }
}

struct WatchTemplateView: View {
    let template: WorkoutTemplate
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        List {
            Button {
                model.start(template: template)
            } label: {
                Label("Démarrer", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .listItemTint(WatchTheme.accent)
            .accessibilityIdentifier("watch.start")
            ForEach(template.orderedExercises) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.exercise?.name ?? item.exerciseId).font(.footnote.weight(.semibold))
                    Text("\(item.targetSets) × \(item.repRangeLabel)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(template.name)
    }
}

// MARK: - Active workout

struct WatchActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    @Environment(WatchAppModel.self) private var model
    @State private var page = 1

    var body: some View {
        TabView(selection: $page) {
            WatchControlsView(session: session).tag(0)
            WatchSetTrackerView(session: session).tag(1)
            WatchMetricsView(session: session).tag(2)
        }
        .tabViewStyle(.page)
        .overlay {
            if model.restEnd != nil {
                WatchRestView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: model.restEnd != nil)
    }
}

struct WatchControlsView: View {
    let session: WorkoutSession
    @Environment(WatchAppModel.self) private var model
    @State private var confirmDiscard = false
    @State private var isFinishing = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                control(session.state == .paused ? "Reprendre" : "Pause",
                        session.state == .paused ? "play.fill" : "pause.fill", .yellow) {
                    model.togglePause(session)
                }
                .accessibilityIdentifier("watch.pause")
                control("Terminer", "checkmark", WatchTheme.positive) {
                    isFinishing = true
                    Task { await model.finish(session) }
                }
                .disabled(isFinishing)
                .accessibilityIdentifier("watch.finish")
            }
            control("Abandonner", "xmark", .red) { confirmDiscard = true }
        }
        .padding(.horizontal, 4)
        .confirmationDialog("Abandonner la séance ?", isPresented: $confirmDiscard) {
            Button("Abandonner", role: .destructive) { model.discard(session) }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func control(_ title: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3.weight(.semibold))
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .tint(color)
    }
}

struct WatchMetricsView: View {
    let session: WorkoutSession
    @Environment(WatchWorkoutManager.self) private var workout

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(FTFormat.duration(session.elapsed(at: context.date)))
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(session.state == .paused ? .yellow : WatchTheme.accent)
                Label(workout.heartRate > 0 ? "\(FTFormat.integer(workout.heartRate)) bpm" : "-- bpm", systemImage: "heart.fill")
                    .foregroundStyle(.red)
                Label(FTFormat.kcal(workout.activeEnergy), systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                Label("\(session.completedSets.count) séries · \(FTFormat.integer(session.totalVolume)) kg", systemImage: "dumbbell.fill")
                    .font(.footnote)
                if !workout.isCollecting {
                    Text(workout.healthState == .authorized ? "Mesures Santé en attente" : workout.healthState.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.title3.monospacedDigit())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WatchSetTrackerView: View {
    @Bindable var session: WorkoutSession
    @Environment(WatchAppModel.self) private var model
    @State private var exerciseIndex: Int?
    @State private var editingWeight = true
    @State private var crown: Double = 0

    private var exercises: [ExerciseLog] { session.orderedExercises }

    /// The exercise to show: the one chosen by the user, or the first with an incomplete set.
    private var currentIndex: Int {
        if let exerciseIndex, exercises.indices.contains(exerciseIndex) { return exerciseIndex }
        return exercises.firstIndex { $0.orderedSets.contains { !$0.isCompleted } } ?? max(0, exercises.count - 1)
    }

    var body: some View {
        if exercises.isEmpty {
            Text("Aucun exercice dans cette séance.").multilineTextAlignment(.center)
        } else {
            let log = exercises[currentIndex]
            let sets = log.orderedSets
            let set = sets.first { !$0.isCompleted } ?? sets.last
            VStack(spacing: 4) {
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                    Text(log.displayName)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Button { move(1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.plain)
                        .disabled(currentIndex >= exercises.count - 1)
                }
                if let set {
                    let done = sets.filter(\.isCompleted).count
                    Text(done == sets.count ? "Toutes les séries sont faites" : "Série \(set.order + 1)/\(sets.count) · obj. \(log.repMin)–\(log.repMax)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        valueBox(title: "kg", value: FTFormat.number(set.weightKg), selected: editingWeight) {
                            editingWeight = true
                            crown = set.weightKg
                        }
                        valueBox(title: "reps", value: "\(set.reps)", selected: !editingWeight) {
                            editingWeight = false
                            crown = Double(set.reps)
                        }
                    }
                    .focusable(true)
                    .digitalCrownRotation($crown, from: 0, through: editingWeight ? 500 : 100,
                                          by: editingWeight ? 0.5 : 1, sensitivity: .low,
                                          isContinuous: false, isHapticFeedbackEnabled: true)
                    .onChange(of: crown) { _, newValue in
                        if editingWeight { set.weightKg = max(0, newValue) } else { set.reps = max(0, Int(newValue.rounded())) }
                        model.data.save()
                    }
                    .onAppear { crown = editingWeight ? set.weightKg : Double(set.reps) }
                    .onChange(of: set.id) { _, _ in crown = editingWeight ? set.weightKg : Double(set.reps) }
                    Button {
                        if !set.isCompleted {
                            model.complete(set, in: session)
                            exerciseIndex = nil
                        } else {
                            model.data.addSet(to: log)
                        }
                    } label: {
                        Label(set.isCompleted ? "Série en plus" : "Valider", systemImage: set.isCompleted ? "plus" : "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(set.isCompleted ? .gray : WatchTheme.positive)
                    .accessibilityIdentifier("watch.completeSet")
                }
            }
        }
    }

    private func move(_ delta: Int) {
        let next = min(max(0, currentIndex + delta), exercises.count - 1)
        exerciseIndex = next
    }

    private func valueBox(title: String, value: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(value).font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 12).stroke(selected ? WatchTheme.accent : .gray.opacity(0.4), lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

struct WatchRestView: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = max(0, (model.restEnd ?? context.date).timeIntervalSince(context.date))
            VStack(spacing: 6) {
                Text("Repos").font(.headline).foregroundStyle(WatchTheme.accent)
                ZStack {
                    Circle().stroke(.gray.opacity(0.3), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: model.restTotal > 0 ? remaining / Double(model.restTotal) : 0)
                        .stroke(WatchTheme.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(FTFormat.duration(remaining.rounded(.up)))
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                }
                .frame(width: 104, height: 104)
                HStack {
                    Button("-15") { model.addRest(-15) }
                    Button("Passer") { model.stopRest() }
                        .accessibilityIdentifier("watch.skipRest")
                    Button("+15") { model.addRest(15) }
                }
                .font(.footnote)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
        }
    }
}

struct WatchSummaryView: View {
    let summary: WatchSummary
    @Environment(WatchSyncService.self) private var sync
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Label("Séance terminée", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(WatchTheme.positive)
                row("Durée", FTFormat.durationLong(summary.duration))
                row("Séries", "\(summary.sets)")
                row("Volume", "\(FTFormat.integer(summary.volume)) kg")
                if summary.kcal > 0 { row("Énergie", FTFormat.kcal(summary.kcal)) }
                Text(summary.savedToHealth ? "Enregistrée dans Santé" : "Non enregistrée dans Santé")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(sync.isReachable ? "Envoyée à l'iPhone" : "Sera envoyée à l'iPhone dès qu'il sera à portée")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("OK") { dismiss() }
                    .accessibilityIdentifier("watch.summaryOK")
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.footnote)
    }
}
