import SwiftUI
import SwiftData

/// A program day: view, reorder, edit, add or remove exercises, and start the workout.
struct TemplateDetailView: View {
    @Bindable var template: WorkoutTemplate
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var showPicker = false
    @State private var editing: TemplateExercise?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.focus).font(.subheadline).foregroundStyle(.secondary)
                    let totalSets = template.orderedExercises.reduce(0) { $0 + $1.targetSets }
                    Text("\(template.orderedExercises.count) exercices · \(totalSets) séries · ~\(estimatedMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Section("Exercices") {
                ForEach(template.orderedExercises) { item in
                    Button {
                        editing = item
                    } label: {
                        TemplateExerciseRow(item: item, suggestion: model.data.suggestion(for: item))
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
                Button {
                    showPicker = true
                } label: {
                    Label("Ajouter un exercice", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("template.addExercise")
            }
            Section {
                Button {
                    model.startWorkout(template: template)
                } label: {
                    Label("Démarrer la séance", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("template.start")
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { exercise in
                add(exercise)
            }
        }
        .sheet(item: $editing) { item in
            TemplateExerciseEditor(item: item)
                .presentationDetents([.medium])
        }
    }

    private var estimatedMinutes: Int {
        let seconds = template.orderedExercises.reduce(0) { $0 + $1.targetSets * (45 + $1.restSeconds) }
        return max(10, seconds / 60)
    }

    private func save() {
        template.updatedAt = .now
        model.data.save()
        model.sync.pushProgram()
    }

    private func add(_ exercise: Exercise) {
        let order = (template.orderedExercises.last?.order ?? -1) + 1
        let compound = exercise.isCompound
        let item = TemplateExercise(exerciseId: exercise.id, order: order, targetSets: 3,
                                    repMin: compound ? 8 : 10, repMax: compound ? 10 : 12,
                                    restSeconds: compound ? 120 : 75, startWeightKg: 0)
        context.insert(item)
        item.template = template
        save()
    }

    private func delete(at offsets: IndexSet) {
        let items = template.orderedExercises
        for index in offsets { context.delete(items[index]) }
        save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var items = template.orderedExercises
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() { item.order = index }
        save()
    }
}

struct TemplateExerciseRow: View {
    let item: TemplateExercise
    let suggestion: ProgressionSuggestion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.exercise?.symbol ?? "dumbbell")
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.accent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.exercise?.name ?? item.exerciseId).font(.subheadline.weight(.semibold))
                Text("\(item.targetSets) × \(item.repRangeLabel) reps · repos \(FTFormat.duration(Double(item.restSeconds)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if suggestion.weightKg > 0 {
                Text(FTFormat.weight(suggestion.weightKg))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.subtleFill))
            }
        }
        .contentShape(Rectangle())
    }
}

struct TemplateExerciseEditor: View {
    @Bindable var item: TemplateExercise
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Séries : \(item.targetSets)", value: $item.targetSets, in: 1...10)
                Stepper("Répétitions min : \(item.repMin)", value: $item.repMin, in: 1...50)
                Stepper("Répétitions max : \(item.repMax)", value: $item.repMax, in: item.repMin...60)
                Stepper("Repos : \(FTFormat.duration(Double(item.restSeconds)))", value: $item.restSeconds, in: 15...600, step: 15)
                HStack {
                    Text("Charge de départ")
                    Spacer()
                    DecimalField(title: "Charge", value: $item.startWeightKg, suffix: "kg", width: 70)
                }
                if let exercise = item.exercise {
                    NavigationLink("Voir la fiche de l'exercice") { ExerciseDetailView(exercise: exercise) }
                }
            }
            .navigationTitle(item.exercise?.name ?? "Exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        if item.repMax < item.repMin { item.repMax = item.repMin }
                        item.template?.updatedAt = .now
                        model.data.save()
                        model.sync.pushProgram()
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Searchable exercise list used to add an exercise to a program or a workout.
struct ExercisePickerView: View {
    var onPick: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var muscle: MuscleGroup?

    var body: some View {
        NavigationStack {
            ExerciseListContent(query: query, muscle: $muscle) { exercise in
                Button {
                    onPick(exercise)
                    dismiss()
                } label: {
                    ExerciseRow(exercise: exercise)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pick.\(exercise.id)")
            }
            .searchable(text: $query, prompt: "Rechercher un exercice")
            .navigationTitle("Ajouter un exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
    }
}

struct ExerciseLibraryView: View {
    @State private var query = ""
    @State private var muscle: MuscleGroup?

    var body: some View {
        ExerciseListContent(query: query, muscle: $muscle) { exercise in
            NavigationLink {
                ExerciseDetailView(exercise: exercise)
            } label: {
                ExerciseRow(exercise: exercise)
            }
        }
        .searchable(text: $query, prompt: "Rechercher un exercice")
        .navigationTitle("Bibliothèque")
    }
}

struct ExerciseListContent<RowContent: View>: View {
    var query: String
    @Binding var muscle: MuscleGroup?
    @ViewBuilder var row: (Exercise) -> RowContent

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(nil, "Tous")
                        ForEach(MuscleGroup.allCases) { chip($0, $0.label) }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            let results = ExerciseCatalog.search(query, muscle: muscle)
            Section("\(results.count) exercices") {
                ForEach(results) { row($0) }
            }
        }
    }

    private func chip(_ value: MuscleGroup?, _ title: String) -> some View {
        Button(title) { muscle = value }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(muscle == value ? Theme.accent : Theme.subtleFill))
            .foregroundStyle(muscle == value ? .white : .primary)
            .buttonStyle(.plain)
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.accent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.subheadline.weight(.semibold))
                Text("\(exercise.primary.label) · \(exercise.equipment.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
