import SwiftUI

/// First-launch flow: profile, goal, nutrition targets and Apple Health permission.
struct OnboardingView: View {
    @Bindable var profile: UserProfile
    @Environment(AppModel.self) private var model
    @Environment(HealthKitService.self) private var health
    @State private var step = 0
    private let lastStep = 4

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 {
                ProgressView(value: Double(step), total: Double(lastStep))
                    .tint(Theme.accent)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }
            TabView(selection: $step) {
                welcome.tag(0)
                profileStep.tag(1)
                goalStep.tag(2)
                targetsStep.tag(3)
                healthStep.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)

            HStack(spacing: 12) {
                if step > 0 {
                    Button("Retour") { withAnimation { step -= 1 } }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Button(step == lastStep ? "Terminer" : (step == 0 ? "Commencer" : "Continuer")) {
                    if step == lastStep {
                        model.completeOnboarding(profile)
                    } else {
                        withAnimation { step += 1 }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("onboarding.next")
            }
            .padding(24)
        }
        .background(Theme.background)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 110, height: 110)
                .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.accentGradient))
                .shadow(color: Theme.accent.opacity(0.35), radius: 20, y: 10)
            VStack(spacing: 8) {
                Text("Bienvenue sur FitTrack").font(.largeTitle.weight(.bold))
                Text("Votre coach musculation et nutrition, sur iPhone et Apple Watch.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 14) {
                feature("figure.strengthtraining.traditional", "Programme personnalisé de 5 séances par semaine")
                feature("fork.knife", "Suivi des calories et des macronutriments, préférence halal")
                feature("applewatch", "Séances sur Apple Watch, synchronisées avec l'iPhone")
                feature("heart.fill", "Intégration à l'app Santé")
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
            Text(text).font(.subheadline)
        }
    }

    private var profileStep: some View {
        Form {
            Section {
                Text("Votre profil").font(.title.weight(.bold)).listRowBackground(Color.clear)
                Text("Ces informations servent à calculer vos besoins. Vous pourrez les modifier à tout moment.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            Section("Identité") {
                TextField("Prénom (facultatif)", text: $profile.firstName)
                    .textContentType(.givenName)
                Picker("Sexe", selection: $profile.sex) {
                    ForEach(Sex.allCases) { Text($0.label).tag($0) }
                }
                Stepper("Âge : \(profile.age) ans", value: $profile.age, in: 14...90)
            }
            Section("Mensurations") {
                Stepper("Taille : \(FTFormat.centimeters(profile.heightCm))", value: $profile.heightCm, in: 120...230, step: 1)
                HStack {
                    Text("Poids")
                    Spacer()
                    DecimalField(title: "Poids", value: $profile.weightKg, suffix: "kg", width: 80)
                }
            }
            Section("Niveau") {
                Picker("Niveau", selection: $profile.level) {
                    ForEach(FitnessLevel.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var goalStep: some View {
        Form {
            Section {
                Text("Votre objectif").font(.title.weight(.bold)).listRowBackground(Color.clear)
            }
            Section {
                ForEach(FitnessGoal.allCases) { goal in
                    Button {
                        profile.goal = goal
                    } label: {
                        HStack {
                            Text(goal.label).foregroundStyle(.primary)
                            Spacer()
                            if profile.goal == goal {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }
            Section("Entraînement") {
                Stepper("\(profile.sessionsPerWeek) séances par semaine", value: $profile.sessionsPerWeek, in: 2...6)
                HStack {
                    Text("Poids cible")
                    Spacer()
                    DecimalField(title: "Poids cible", value: $profile.targetWeightKg, suffix: "kg", width: 80)
                }
            }
            Section {
                Toggle("Alimentation halal", isOn: $profile.halalOnly)
            } footer: {
                Text("FitTrack met en avant les produits déclarés halal et signale les ingrédients potentiellement non halal (porc, alcool, gélatine…). Un produit n'est jamais présenté comme halal sans information fiable : vérifiez toujours la certification sur l'emballage.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var targetsStep: some View {
        let t = profile.targets
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Vos objectifs quotidiens").font(.title.weight(.bold))
                Text("Calculés avec la formule de Mifflin-St Jeor pour « \(profile.goal.shortLabel.lowercased()) ».")
                    .foregroundStyle(.secondary)
                VStack(spacing: 6) {
                    Text(FTFormat.kcal(t.calories))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accentGradient)
                    Text("Maintien estimé : \(FTFormat.kcal(t.maintenance))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .cardStyle()
                HStack(spacing: 12) {
                    macroTile("Protéines", t.protein, Theme.protein)
                    macroTile("Glucides", t.carbs, Theme.carbs)
                    macroTile("Lipides", t.fat, Theme.fat)
                }
                Text("Les protéines sont fixées à \(FTFormat.number(profile.goal.proteinPerKg)) g par kg pour préserver et développer vos muscles. Ces valeurs sont indicatives et ne remplacent pas l'avis d'un professionnel de santé.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }

    private func macroTile(_ title: String, _ grams: Double, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(FTFormat.grams(grams)).font(.title3.weight(.bold)).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
    }

    private var healthStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(.pink)
            Text("Apple Santé").font(.title.weight(.bold))
            Text("FitTrack peut lire votre poids, vos pas, votre énergie active et votre fréquence cardiaque, et enregistrer vos séances, votre poids et vos repas dans Santé. Vos données restent sur vos appareils.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            switch health.status {
            case .unavailable:
                Label("Santé n'est pas disponible sur cet appareil.", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
            case .notDetermined:
                Button("Connecter Apple Santé") {
                    Task {
                        profile.healthKitPrompted = true
                        await health.requestAuthorization()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("onboarding.connectHealth")
                Text("Vous pouvez aussi le faire plus tard depuis l'onglet Profil.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            default:
                Label(health.status.label, systemImage: health.status == .denied ? "xmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(health.status == .denied ? .orange : Theme.positive)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}
