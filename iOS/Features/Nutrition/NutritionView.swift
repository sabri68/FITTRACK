import SwiftUI
import SwiftData

/// Daily food journal.
struct NutritionView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @State private var day = Calendar.fitTrack.startOfDay(for: .now)
    @State private var addingMeal: MealType?
    @State private var editing: FoodEntry?

    var body: some View {
        NavigationStack {
            DayJournal(day: day, targets: profiles.first?.targets,
                       onAdd: { addingMeal = $0 }, onEdit: { editing = $0 })
                .navigationTitle("Nutrition")
                .toolbar {
                    ToolbarItem(placement: .principal) { daySelector }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            addingMeal = MealType.suggested()
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }
                        .accessibilityLabel("Ajouter un aliment")
                        .accessibilityIdentifier("nutrition.add")
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .sheet(item: $addingMeal) { meal in
                    AddFoodView(meal: meal, day: day, halalOnly: profiles.first?.halalOnly ?? true)
                }
                .sheet(item: $editing) { entry in
                    EditFoodEntryView(entry: entry)
                        .presentationDetents([.medium, .large])
                }
        }
    }

    private var daySelector: some View {
        HStack(spacing: 14) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Jour précédent")
            VStack(spacing: 0) {
                Text(dayTitle).font(.headline)
                Text(FTFormat.dayMedium(day)).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(minWidth: 130)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .disabled(Calendar.fitTrack.isDateInToday(day))
                .accessibilityLabel("Jour suivant")
        }
    }

    private var dayTitle: String {
        let cal = Calendar.fitTrack
        if cal.isDateInToday(day) { return "Aujourd'hui" }
        if cal.isDateInYesterday(day) { return "Hier" }
        return day.formatted(.dateTime.weekday(.wide).locale(FTFormat.locale)).capitalized(with: FTFormat.locale)
    }

    private func shift(_ days: Int) {
        if let d = Calendar.fitTrack.date(byAdding: .day, value: days, to: day) {
            withAnimation { day = d }
        }
    }
}

/// The list of meals and entries for one day (re-created when the day changes so the query updates).
private struct DayJournal: View {
    let day: Date
    let targets: NutritionTargets?
    var onAdd: (MealType) -> Void
    var onEdit: (FoodEntry) -> Void
    @Environment(AppModel.self) private var model
    @Query private var entries: [FoodEntry]

    init(day: Date, targets: NutritionTargets?, onAdd: @escaping (MealType) -> Void, onEdit: @escaping (FoodEntry) -> Void) {
        self.day = day
        self.targets = targets
        self.onAdd = onAdd
        self.onEdit = onEdit
        let start = Calendar.fitTrack.startOfDay(for: day)
        let end = Calendar.fitTrack.date(byAdding: .day, value: 1, to: start) ?? start
        _entries = Query(filter: #Predicate<FoodEntry> { $0.date >= start && $0.date < end },
                         sort: \FoodEntry.createdAt)
    }

    var body: some View {
        let total = entries.map(\.macros).total
        List {
            Section {
                summary(total)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            ForEach(MealType.allCases) { meal in
                let items = entries.filter { $0.meal == meal }
                Section {
                    ForEach(items) { entry in
                        Button { onEdit(entry) } label: { FoodEntryRow(entry: entry) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for index in offsets { model.deleteFood(items[index]) }
                    }
                    Button {
                        onAdd(meal)
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("nutrition.add.\(meal.rawValue)")
                } header: {
                    HStack {
                        Label(meal.label, systemImage: meal.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .textCase(nil)
                        Spacer()
                        Text(FTFormat.kcal(items.map(\.macros).total.kcal))
                            .font(.caption.monospacedDigit())
                            .textCase(nil)
                    }
                }
            }
        }
    }

    private func summary(_ total: Macros) -> some View {
        let t = targets ?? NutritionTargets(bmr: 0, maintenance: 0, calories: 2000, protein: 120, carbs: 250, fat: 70)
        let remaining = t.calories - total.kcal
        return VStack(spacing: 14) {
            HStack(spacing: 18) {
                ZStack {
                    RingView(progress: t.calories > 0 ? total.kcal / t.calories : 0, lineWidth: 11)
                    VStack(spacing: 0) {
                        Text(FTFormat.integer(total.kcal)).font(.title3.weight(.bold).monospacedDigit())
                        Text("kcal").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 6) {
                    Text(remaining >= 0 ? "Reste \(FTFormat.kcal(remaining))" : "Dépassement de \(FTFormat.kcal(-remaining))")
                        .font(.headline)
                        .foregroundStyle(remaining >= 0 ? Color.primary : Theme.warning)
                        .accessibilityIdentifier("nutrition.remaining")
                    Text("Objectif \(FTFormat.kcal(t.calories))").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            MacroBar(title: "Protéines", value: total.protein, target: t.protein, color: Theme.protein)
            MacroBar(title: "Glucides", value: total.carbs, target: t.carbs, color: Theme.carbs)
            MacroBar(title: "Lipides", value: total.fat, target: t.fat, color: Theme.fat)
        }
        .cardStyle()
        .padding(.vertical, 4)
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name).font(.subheadline.weight(.medium)).lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(FTFormat.grams(entry.quantityGrams))\(entry.brand.isEmpty ? "" : " · \(entry.brand)")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if entry.halal == .potentiallyNonHalal || entry.halal == .unknown {
                        HalalBadge(status: entry.halal, compact: true)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(FTFormat.kcal(entry.macros.kcal)).font(.subheadline.weight(.semibold).monospacedDigit())
                Text("P \(FTFormat.integer(entry.macros.protein)) · G \(FTFormat.integer(entry.macros.carbs)) · L \(FTFormat.integer(entry.macros.fat))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Edit quantity or meal of a logged food.
struct EditFoodEntryView: View {
    @Bindable var entry: FoodEntry
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(entry.name).font(.headline)
                    if !entry.brand.isEmpty { Text(entry.brand).foregroundStyle(.secondary) }
                    HalalBadge(status: entry.halal)
                }
                Section("Quantité") {
                    HStack {
                        Text("Quantité")
                        Spacer()
                        DecimalField(title: "g", value: $entry.quantityGrams, suffix: "g", width: 80)
                    }
                    Picker("Repas", selection: $entry.meal) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("Apports") {
                    LabeledContent("Énergie", value: FTFormat.kcal(entry.macros.kcal))
                    LabeledContent("Protéines", value: FTFormat.grams(entry.macros.protein))
                    LabeledContent("Glucides", value: FTFormat.grams(entry.macros.carbs))
                    LabeledContent("Lipides", value: FTFormat.grams(entry.macros.fat))
                    LabeledContent("Source", value: entry.source.label)
                }
                Section {
                    Button("Supprimer", role: .destructive) {
                        let doomed = entry
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            model.deleteFood(doomed)
                        }
                    }
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        if entry.quantityGrams <= 0 { entry.quantityGrams = 1 }
                        model.data.save()
                        model.resyncFoodWithHealth(entry)
                        dismiss()
                    }
                }
            }
        }
    }
}
