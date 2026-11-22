import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    var body: some View {
        Group {
            if model.isResetting {
                ProgressView("Suppression des données…")
            } else if let profile = profiles.first {
                if profile.onboardingCompleted {
                    MainTabView()
                } else {
                    OnboardingView(profile: profile)
                }
            } else {
                ProgressView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: profiles.first?.onboardingCompleted)
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("Accueil", systemImage: "house.fill", value: AppTab.dashboard) {
                DashboardView()
            }
            Tab("Entraînement", systemImage: "dumbbell.fill", value: AppTab.workout) {
                WorkoutHomeView()
            }
            Tab("Nutrition", systemImage: "fork.knife", value: AppTab.nutrition) {
                NutritionView()
            }
            Tab("Progrès", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressDashboardView()
            }
            Tab("Profil", systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView()
            }
        }
        .fullScreenCover(item: $model.presentedSession) { session in
            ActiveWorkoutView(session: session)
        }
        .overlay(alignment: .top) {
            if let warning = model.startupWarning {
                Text(warning)
                    .font(.caption)
                    .padding(10)
                    .background(.orange.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }
}
