import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Environment(AppModel.self) private var model
    @Query(filter: #Predicate<WorkoutSession> { $0.stateRaw == "finished" },
           sort: \WorkoutSession.startDate, order: .reverse)
    private var sessions: [WorkoutSession]

    struct MonthGroup: Identifiable {
        var id: Date { month }
        var month: Date
        var sessions: [WorkoutSession]
    }

    private var grouped: [MonthGroup] {
        let cal = Calendar.fitTrack
        let groups = Dictionary(grouping: sessions) {
            cal.date(from: cal.dateComponents([.year, .month], from: $0.startDate)) ?? $0.startDate
        }
        return groups.keys.sorted(by: >).map { MonthGroup(month: $0, sessions: groups[$0] ?? []) }
    }

    var body: some View {
        List {
            if sessions.isEmpty {
                EmptyStateView(symbol: "clock.arrow.circlepath", title: "Aucune séance",
                               message: "Terminez une séance pour la retrouver ici.")
            }
            ForEach(grouped) { group in
                Section(group.month.formatted(.dateTime.month(.wide).year().locale(FTFormat.locale)).capitalized(with: FTFormat.locale)) {
                    ForEach(group.sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRow(session: session)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { model.data.discard(group.sessions[index]) }
                    }
                }
            }
        }
        .navigationTitle("Historique")
    }
}

struct SessionDetailView: View {
    @Bindable var session: WorkoutSession
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: "\(FTFormat.dayLong(session.startDate)) à \(FTFormat.time(session.startDate))")
                LabeledContent("Durée", value: FTFormat.durationLong(session.elapsed()))
                LabeledContent("Séries validées", value: "\(session.completedSets.count)")
                LabeledContent("Volume total", value: "\(FTFormat.integer(session.totalVolume)) kg")
                LabeledContent("Appareil", value: session.device.label)
                if session.activeEnergyKcal > 0 {
                    LabeledContent("Énergie active", value: FTFormat.kcal(session.activeEnergyKcal))
                }
                if session.averageHeartRate > 0 {
                    LabeledContent("Fréquence cardiaque moy.", value: "\(FTFormat.integer(session.averageHeartRate)) bpm")
                }
                LabeledContent("Apple Santé", value: session.savedToHealth ? "Enregistrée" : "Non enregistrée")
            }
            ForEach(session.orderedExercises) { log in
                Section(log.displayName) {
                    ForEach(log.orderedSets) { set in
                        HStack {
                            Text("Série \(set.order + 1)")
                            Spacer()
                            Text("\(FTFormat.weight(set.weightKg)) × \(set.reps)")
                                .monospacedDigit()
                                .foregroundStyle(set.isCompleted ? .primary : .tertiary)
                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(set.isCompleted ? Theme.positive : .secondary)
                        }
                    }
                }
            }
            Section("Notes") {
                TextField("Ajouter une note…", text: $session.notes, axis: .vertical)
                    .onSubmit { model.data.save() }
                    .onChange(of: session.notes) { _, _ in model.data.save() }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
