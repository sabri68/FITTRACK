import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            Group {
                if let profile = profiles.first {
                    ProfileForm(profile: profile)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Profil")
        }
    }
}

private struct ProfileForm: View {
    @Bindable var profile: UserProfile
    @Environment(AppModel.self) private var model
    @Environment(HealthKitService.self) private var health
    @Environment(PhoneSyncService.self) private var sync
    @Environment(\.openURL) private var openURL
    @State private var showWeightSheet = false
    @State private var confirmRegenerate = false
    @State private var confirmDelete = false
    @State private var useCustomCalories = false

    var body: some View {
        let targets = profile.targets
        Form {
            Section("Informations personnelles") {
                TextField("Prénom", text: $profile.firstName)
                Picker("Sexe", selection: $profile.sex) {
                    ForEach(Sex.allCases) { Text($0.label).tag($0) }
                }
                Stepper("Âge : \(profile.age) ans", value: $profile.age, in: 14...90)
                Stepper("Taille : \(FTFormat.centimeters(profile.heightCm))", value: $profile.heightCm, in: 120...230)
                HStack {
                    Text("Poids actuel")
                    Spacer()
                    Text(FTFormat.weight(profile.weightKg)).foregroundStyle(.secondary)
                    Button("Peser") { showWeightSheet = true }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("profile.weigh")
                }
                HStack {
                    Text("Poids cible")
                    Spacer()
                    DecimalField(title: "kg", value: $profile.targetWeightKg, suffix: "kg", width: 70)
                }
                Picker("Niveau", selection: $profile.level) {
                    ForEach(FitnessLevel.allCases) { Text($0.label).tag($0) }
                }
            }

            Section("Objectifs et préférences") {
                Picker("Objectif", selection: $profile.goal) {
                    ForEach(FitnessGoal.allCases) { Text($0.shortLabel).tag($0) }
                }
                Stepper("\(profile.sessionsPerWeek) séances / semaine", value: $profile.sessionsPerWeek, in: 2...6)
                Toggle("Alimentation halal", isOn: $profile.halalOnly)
                    .accessibilityIdentifier("profile.halal")
            }

            Section {
                LabeledContent("Métabolisme de base", value: FTFormat.kcal(targets.bmr))
                LabeledContent("Maintien estimé", value: FTFormat.kcal(targets.maintenance))
                Toggle("Objectif calorique personnalisé", isOn: $useCustomCalories)
                if useCustomCalories {
                    Stepper("Objectif : \(FTFormat.kcal(Double(profile.customCalories)))",
                            value: $profile.customCalories, in: 1000...6000, step: 50)
                } else {
                    LabeledContent("Objectif calorique", value: FTFormat.kcal(targets.calories))
                }
                LabeledContent("Protéines", value: FTFormat.grams(targets.protein))
                LabeledContent("Glucides", value: FTFormat.grams(targets.carbs))
                LabeledContent("Lipides", value: FTFormat.grams(targets.fat))
            } header: {
                Text("Objectifs nutritionnels quotidiens")
            } footer: {
                Text("Calcul : Mifflin-St Jeor × niveau d'activité, ajusté selon votre objectif. Valeurs indicatives.")
            }

            Section {
                Button("Régénérer mon programme (\(min(max(profile.sessionsPerWeek, 3), 5)) jours)") { confirmRegenerate = true }
                    .accessibilityIdentifier("profile.regenerate")
            } header: {
                Text("Programme d'entraînement")
            } footer: {
                Text("Remplace les séances du programme par le programme débutant adapté à votre fréquence. L'historique est conservé.")
            }

            Section {
                HStack {
                    Label("Apple Santé", systemImage: "heart.fill").foregroundStyle(.pink)
                    Spacer()
                    Text(health.status.label).foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile.healthStatus")
                }
                if health.status == .notDetermined {
                    Button("Connecter Apple Santé") {
                        Task {
                            profile.healthKitPrompted = true
                            await health.requestAuthorization()
                        }
                    }
                } else if health.status == .denied || health.status == .partiallyAuthorized {
                    Button("Modifier l'accès dans Réglages") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                if let error = health.lastError { Text(error).font(.footnote).foregroundStyle(.red) }
            } header: {
                Text("Connexions")
            } footer: {
                Text("Pour modifier les autorisations : app Santé › Profil › Apps › FitTrack.")
            }

            Section {
                HStack {
                    Label("Apple Watch", systemImage: "applewatch")
                    Spacer()
                    Text(sync.statusLabel).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                }
                if let last = sync.lastProgramPush {
                    LabeledContent("Programme envoyé", value: "\(FTFormat.dayMedium(last)) \(FTFormat.time(last))")
                }
                if sync.importedCount > 0 {
                    LabeledContent("Séances reçues de la montre", value: "\(sync.importedCount)")
                }
                Button("Envoyer le programme à la montre") { sync.pushProgram() }
                    .disabled(!sync.isWatchAppInstalled)
            }

            Section {
                HStack {
                    Label("Synchronisation iCloud", systemImage: "icloud")
                    Spacer()
                    Text(Persistence.isICloudSyncCompiledIn ? "Activée" : "Désactivée").foregroundStyle(.secondary)
                }
            } footer: {
                Text(Persistence.isICloudSyncCompiledIn
                     ? "Vos données sont synchronisées dans votre iCloud privé."
                     : "Vos données sont enregistrées sur cet iPhone. La synchronisation iCloud nécessite un compte Apple Developer payant ; elle pourra être activée plus tard sans perte de données (voir README).")
            }

            Section {
                Button("Effacer toutes mes données", role: .destructive) { confirmDelete = true }
            } footer: {
                Text("FitTrack \(AppInfo.version) · Données d'aliments : Open Food Facts (licence ODbL).")
            }
        }
        .onAppear { useCustomCalories = profile.customCalories > 0 }
        .onChange(of: useCustomCalories) { _, on in
            if on && profile.customCalories == 0 {
                profile.customCalories = Int((NutritionCalculator.targets(for: profile.nutritionInput).calories / 50).rounded() * 50)
            }
            if !on { profile.customCalories = 0 }
            touch()
        }
        .onChange(of: profile.sex) { _, _ in touch() }
        .onChange(of: profile.age) { _, _ in touch() }
        .onChange(of: profile.heightCm) { _, _ in touch() }
        .onChange(of: profile.targetWeightKg) { _, _ in touch() }
        .onChange(of: profile.goal) { _, _ in touch() }
        .onChange(of: profile.sessionsPerWeek) { _, _ in touch() }
        .onChange(of: profile.halalOnly) { _, _ in touch() }
        .onChange(of: profile.levelRaw) { _, _ in touch() }
        .onChange(of: profile.customCalories) { _, _ in touch() }
        .onChange(of: profile.firstName) { _, _ in touch() }
        .sheet(isPresented: $showWeightSheet) {
            WeightEntrySheet(initial: profile.weightKg).presentationDetents([.height(320)])
        }
        .confirmationDialog("Régénérer le programme ?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Régénérer", role: .destructive) {
                model.data.replaceProgram(sessionsPerWeek: profile.sessionsPerWeek)
                model.sync.pushProgram()
            }
        } message: {
            Text("Vos modifications du programme actuel seront perdues.")
        }
        .confirmationDialog("Effacer toutes les données ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Tout effacer", role: .destructive) {
                model.resetAllData()
            }
        } message: {
            Text("Séances, repas, pesées et profil seront supprimés de cet appareil. Les données déjà enregistrées dans Santé ne sont pas effacées.")
        }
    }

    private func touch() {
        profile.updatedAt = .now
        model.data.save()
    }
}
