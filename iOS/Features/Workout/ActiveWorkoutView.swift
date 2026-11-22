import SwiftUI
import SwiftData

/// Live workout: record sets, edit weights and reps, rest timer, pause/resume, finish.
/// Every change is saved immediately so an unexpected termination loses nothing.
struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var showFinishDialog = false
    @State private var summary: WorkoutSummary?
    @State private var detailExercise: Exercise?

    var body: some View {
        NavigationStack {
            List {
                Section { header }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                ForEach(session.orderedExercises) { log in
                    ExerciseLogSection(log: log,
                                       onCompleted: { set in setCompleted(set, in: log) },
                                       onShowInfo: { detailExercise = log.exercise })
                }

                Section {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Ajouter un exercice", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("active.addExerciseBottom")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Réduire")
                    .accessibilityIdentifier("active.minimize")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Ajouter un exercice")
                    .accessibilityIdentifier("active.addExercise")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terminer") { showFinishDialog = true }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("active.finish")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.restTimer.isRunning {
                    RestTimerBar(timer: model.restTimer)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.restTimer.isRunning)
            .confirmationDialog("Terminer la séance ?", isPresented: $showFinishDialog, titleVisibility: .visible) {
                Button("Terminer et enregistrer") { finish() }
                    .accessibilityIdentifier("active.confirmFinish")
                Button("Abandonner la séance", role: .destructive) { discard() }
                Button("Continuer la séance", role: .cancel) {}
            } message: {
                Text("\(session.completedSets.count) séries validées.")
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { exercise in
                    model.data.addExercise(exercise.id, to: session)
                }
            }
            .sheet(item: $detailExercise) { exercise in
                NavigationStack { ExerciseDetailView(exercise: exercise) }
            }
            .sheet(item: $summary, onDismiss: { dismiss() }) { summary in
                WorkoutSummaryView(summary: summary)
            }
        }
        .interactiveDismissDisabled(summary != nil)
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.state == .paused ? "En pause" : "Durée")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(session.state == .paused ? .orange : .secondary)
                    Text(FTFormat.duration(session.elapsed(at: context.date)))
                        .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("active.timer")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(session.completedSets.count) séries").font(.subheadline.weight(.semibold))
                    Text("\(FTFormat.integer(session.totalVolume)) kg").font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    togglePause()
                } label: {
                    Image(systemName: session.state == .paused ? "play.fill" : "pause.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(session.state == .paused ? AnyShapeStyle(Theme.positive) : AnyShapeStyle(Theme.accentGradient)))
                }
                .accessibilityLabel(session.state == .paused ? "Reprendre" : "Pause")
                .accessibilityIdentifier("active.pause")
            }
            .cardStyle()
        }
    }

    private func togglePause() {
        if session.state == .paused {
            session.resume()
        } else {
            session.pause()
            model.restTimer.stop()
        }
        model.data.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func setCompleted(_ set: SetLog, in log: ExerciseLog) {
        if session.state == .paused { session.resume() }
        model.data.completeSet(set)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let remainingSets = session.orderedExercises.flatMap(\.orderedSets).filter { !$0.isCompleted }
        if !remainingSets.isEmpty {
            model.restTimer.start(seconds: log.restSeconds)
        }
    }

    private func finish() {
        model.restTimer.stop()
        let records = newRecords()
        Task {
            await model.finishWorkout(session)
            summary = WorkoutSummary(name: session.name, duration: session.elapsed(),
                                     sets: session.completedSets.count, volume: session.totalVolume,
                                     records: records, savedToHealth: session.savedToHealth,
                                     healthAvailable: model.health.canWrite)
        }
    }

    private func discard() {
        model.restTimer.stop()
        let doomed = session
        let data = model.data
        model.presentedSession = nil
        // Delete after the screen is gone so no view observes a deleted object.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            data.discard(doomed)
        }
    }

    /// Exercises where this session beats the previous best estimated 1RM.
    private func newRecords() -> [String] {
        session.orderedExercises.compactMap { log in
            let current = log.orderedSets.filter { $0.isCompleted && $0.reps > 0 }
                .map { StrengthMath.estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0
            guard current > 0 else { return nil }
            let previous = model.data.allSamples(exerciseId: log.exerciseId)
                .map { StrengthMath.estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0
            return current > previous ? log.displayName : nil
        }
    }
}

/// One exercise in the live workout with its sets.
struct ExerciseLogSection: View {
    @Bindable var log: ExerciseLog
    var onCompleted: (SetLog) -> Void
    var onShowInfo: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            HStack(spacing: 8) {
                Text("Série").frame(width: 40, alignment: .leading)
                Spacer()
                Text("Charge").frame(width: 110)
                Text("Reps").frame(width: 104)
                Text("").frame(width: 34)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(log.orderedSets) { set in
                SetRowView(set: set, index: set.order + 1) {
                    onCompleted(set)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        model.data.removeSet(set)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
            Button {
                model.data.addSet(to: log)
            } label: {
                Label("Ajouter une série", systemImage: "plus")
                    .font(.subheadline)
            }
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.displayName).font(.headline).foregroundStyle(.primary).textCase(nil)
                    Text("Objectif \(log.repMin)–\(log.repMax) reps · repos \(FTFormat.duration(Double(log.restSeconds)))")
                        .font(.caption)
                        .textCase(nil)
                }
                Spacer()
                Menu {
                    Button { onShowInfo() } label: { Label("Fiche de l'exercice", systemImage: "info.circle") }
                    Button { model.data.addSet(to: log) } label: { Label("Ajouter une série", systemImage: "plus") }
                    Button(role: .destructive) {
                        model.data.removeExercise(log)
                    } label: {
                        Label("Retirer l'exercice", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                }
                .accessibilityLabel("Options de l'exercice")
            }
        }
    }
}

struct SetRowView: View {
    @Bindable var set: SetLog
    var index: Int
    var onComplete: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.subheadline.weight(.bold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(set.isCompleted ? Theme.positive.opacity(0.18) : Theme.subtleFill))
                .frame(width: 40, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                DecimalField(title: "kg", value: $set.weightKg, width: 56)
                    .font(.body.monospacedDigit())
                Text("kg").font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 110)
            HStack(spacing: 2) {
                stepButton("minus") { if set.reps > 0 { set.reps -= 1; model.data.save() } }
                Text("\(set.reps)")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 28)
                stepButton("plus") { set.reps += 1; model.data.save() }
            }
            .frame(width: 104)
            Button {
                if set.isCompleted {
                    model.data.completeSet(set, completed: false)
                } else {
                    onComplete()
                }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Theme.positive : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .frame(width: 34)
            .accessibilityLabel(set.isCompleted ? "Série validée" : "Valider la série")
            .accessibilityIdentifier("set.complete")
        }
        .onChange(of: set.weightKg) { _, _ in model.data.save() }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.subtleFill))
        }
        .buttonStyle(.borderless)
    }
}

struct RestTimerBar: View {
    let timer: RestTimerController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = timer.remaining(at: context.date)
            HStack(spacing: 14) {
                ZStack {
                    RingView(progress: timer.totalSeconds > 0 ? remaining / Double(timer.totalSeconds) : 0,
                             lineWidth: 5, track: .white.opacity(0.25))
                    Image(systemName: "timer").font(.caption.bold())
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Repos").font(.caption.weight(.semibold)).opacity(0.85)
                    Text(FTFormat.duration(remaining.rounded(.up)))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .accessibilityIdentifier("rest.remaining")
                }
                Spacer()
                Button("−15 s") { timer.add(-15) }
                Button("+15 s") { timer.add(15) }
                Button {
                    timer.stop()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .accessibilityLabel("Passer le repos")
                .accessibilityIdentifier("rest.skip")
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)
            .foregroundStyle(.white)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(0.88)))
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
    }
}

struct WorkoutSummary: Identifiable {
    let id = UUID()
    var name: String
    var duration: TimeInterval
    var sets: Int
    var volume: Double
    var records: [String]
    var savedToHealth: Bool
    var healthAvailable: Bool
}

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.accentGradient)
                .symbolEffect(.bounce, value: summary.id)
            Text("Séance terminée !").font(.largeTitle.weight(.bold))
            Text(summary.name).font(.headline).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                StatTile(title: "Durée", value: FTFormat.durationLong(summary.duration), symbol: "clock.fill")
                StatTile(title: "Séries", value: "\(summary.sets)", symbol: "checklist", tint: Theme.positive)
                StatTile(title: "Volume", value: "\(FTFormat.integer(summary.volume)) kg", symbol: "scalemass.fill", tint: Theme.protein)
            }
            if !summary.records.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Nouveaux records", systemImage: "trophy.fill").font(.headline).foregroundStyle(.yellow)
                    ForEach(summary.records, id: \.self) { Text("• \($0)") }
                }
                .cardStyle()
            }
            Label(summary.savedToHealth ? "Enregistrée dans Santé" : (summary.healthAvailable ? "Non enregistrée dans Santé" : "Santé non connecté"),
                  systemImage: summary.savedToHealth ? "heart.fill" : "heart.slash")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Fermer") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("summary.close")
        }
        .padding(24)
    }
}
