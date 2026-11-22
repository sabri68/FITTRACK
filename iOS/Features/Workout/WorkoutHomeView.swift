import SwiftUI
import SwiftData

struct WorkoutHomeView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \WorkoutTemplate.dayIndex) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]

    private var finished: [WorkoutSession] { sessions.filter { $0.state == .finished } }
    private var unfinished: WorkoutSession? { sessions.first { $0.state != .finished } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    if let unfinished {
                        Button {
                            model.presentedSession = unfinished
                        } label: {
                            Label("Reprendre « \(unfinished.name) »", systemImage: "play.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    SectionHeader(title: "Mon programme")
                    ForEach(templates) { template in
                        NavigationLink(value: template) {
                            TemplateCard(template: template, lastDone: lastDate(for: template))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("template.\(template.dayIndex)")
                    }
                    if templates.isEmpty {
                        EmptyStateView(symbol: "list.bullet.clipboard", title: "Aucun programme",
                                       message: "Générez votre programme depuis l'onglet Profil.")
                    }

                    HStack(spacing: 12) {
                        Button {
                            model.startWorkout(template: nil)
                        } label: {
                            Label("Séance libre", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("workout.freeSession")
                        NavigationLink {
                            ExerciseLibraryView()
                        } label: {
                            Label("Exercices", systemImage: "books.vertical.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("workout.library")
                    }

                    SectionHeader(title: "Historique")
                        .overlay(alignment: .trailing) {
                            if !finished.isEmpty {
                                NavigationLink("Tout voir") { WorkoutHistoryView() }
                                    .font(.subheadline.weight(.semibold))
                                    .accessibilityIdentifier("workout.history")
                            }
                        }
                    if finished.isEmpty {
                        EmptyStateView(symbol: "clock.arrow.circlepath", title: "Pas encore de séance",
                                       message: "Vos séances terminées apparaîtront ici.")
                            .cardStyle()
                    } else {
                        VStack(spacing: 0) {
                            ForEach(finished.prefix(5)) { session in
                                NavigationLink {
                                    SessionDetailView(session: session)
                                } label: {
                                    SessionRow(session: session)
                                }
                                .buttonStyle(.plain)
                                if session.id != finished.prefix(5).last?.id { Divider() }
                            }
                        }
                        .cardStyle(padding: 12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Theme.groupedBackground)
            .navigationTitle("Entraînement")
            .navigationDestination(for: WorkoutTemplate.self) { TemplateDetailView(template: $0) }
        }
    }

    private func lastDate(for template: WorkoutTemplate) -> Date? {
        finished.first { $0.templateUUID == template.uuid }?.startDate
    }
}

struct TemplateCard: View {
    let template: WorkoutTemplate
    let lastDone: Date?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: template.symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accentGradient))
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name).font(.headline)
                Text(template.focus).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Text(lastDone.map { "Dernière fois : \(FTFormat.dayMedium($0))" } ?? "\(template.orderedExercises.count) exercices")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .cardStyle(padding: 14)
    }
}

struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if session.device == .watch {
                        Image(systemName: "applewatch").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("\(FTFormat.dayMedium(session.startDate)) · \(FTFormat.durationLong(session.elapsed()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(session.completedSets.count) séries").font(.caption.weight(.semibold))
                Text("\(FTFormat.integer(session.totalVolume)) kg").font(.caption).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
