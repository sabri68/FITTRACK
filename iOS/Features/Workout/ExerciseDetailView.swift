import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]

    /// Best estimated 1RM per session (oldest first).
    private var progression: [ProgressPoint] {
        sessions.filter { $0.state == .finished }.reversed().compactMap { session in
            let sets = session.orderedExercises.filter { $0.exerciseId == exercise.id }
                .flatMap(\.orderedSets).filter { $0.isCompleted && $0.reps > 0 }
            guard !sets.isEmpty else { return nil }
            let best = sets.map { StrengthMath.estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0
            let top = sets.map(\.weightKg).max() ?? 0
            return ProgressPoint(date: session.startDate, oneRM: best, top: top)
        }
    }

    var body: some View {
        let samples = model.data.allSamples(exerciseId: exercise.id)
        let record = StrengthMath.personalRecord(exerciseId: exercise.id, samples: samples)
        let points = progression
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                hero
                if let record {
                    HStack(spacing: 12) {
                        StatTile(title: "Charge max", value: FTFormat.weight(record.maxWeightKg),
                                 subtitle: "× \(record.maxWeightReps) reps", symbol: "trophy.fill", tint: .yellow)
                        StatTile(title: "1RM estimé", value: FTFormat.weight(record.bestEstimatedOneRepMax),
                                 subtitle: "Formule d'Epley", symbol: "bolt.fill", tint: Theme.accent)
                    }
                }
                if points.count >= 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progression (1RM estimé)").font(.headline)
                        Chart(points) { p in
                            LineMark(x: .value("Date", p.date), y: .value("1RM", p.oneRM))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Theme.accent)
                            PointMark(x: .value("Date", p.date), y: .value("1RM", p.oneRM))
                                .foregroundStyle(Theme.accent)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 180)
                    }
                    .cardStyle()
                } else if !samples.isEmpty {
                    Text("Le graphique de progression apparaîtra après deux séances avec cet exercice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .cardStyle()
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Exécution").font(.headline)
                    ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Theme.accent))
                            Text(step).font(.subheadline)
                        }
                    }
                }
                .cardStyle()
                if !exercise.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Conseils", systemImage: "lightbulb.fill").font(.headline).foregroundStyle(.orange)
                        ForEach(exercise.tips, id: \.self) { Text("• \($0)").font(.subheadline) }
                    }
                    .cardStyle()
                }
                if let url = exercise.demoSearchURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Voir des démonstrations vidéo", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                if !points.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Historique").font(.headline)
                        ForEach(points.reversed()) { p in
                            HStack {
                                Text(FTFormat.dayMedium(p.date)).font(.subheadline)
                                Spacer()
                                Text("max \(FTFormat.weight(p.top))").font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding()
        }
        .background(Theme.groupedBackground)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: exercise.symbol)
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.accentGradient))
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name).font(.title3.weight(.bold))
                    Text(exercise.equipment.label + (exercise.isCompound ? " · Polyarticulaire" : " · Isolation"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text(exercise.summary).font(.subheadline)
            FlowChips(items: [exercise.primary.label] + exercise.secondary.map(\.label), highlightFirst: true)
        }
        .cardStyle()
    }
}

struct ProgressPoint: Identifiable {
    var id: Date { date }
    var date: Date
    var oneRM: Double
    var top: Double
}

/// Simple wrapping row of chips (muscles).
struct FlowChips: View {
    let items: [String]
    var highlightFirst = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    @ViewBuilder private var chips: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            let primary = highlightFirst && index == 0
            Text(item)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(primary ? Theme.accent.opacity(0.15) : Theme.subtleFill))
                .foregroundStyle(primary ? Theme.accent : .secondary)
        }
    }
}
