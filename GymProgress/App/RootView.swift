import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppErrorCenter.self) private var errorCenter
    @State private var seedError: String?

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "sun.max.fill") }
                .accessibilityIdentifier("tab.today")

            WorkoutCalendarView()
                .tabItem { Label("Календарь", systemImage: "calendar") }
                .accessibilityIdentifier("tab.calendar")

            ExerciseListView()
                .tabItem { Label("Упражнения", systemImage: "dumbbell.fill") }
                .accessibilityIdentifier("tab.exercises")

            ProgressDashboardView()
                .tabItem { Label("Прогресс", systemImage: "chart.line.uptrend.xyaxis") }
                .accessibilityIdentifier("tab.progress")
        }
        .tint(AppTheme.accent)
        .task {
            do {
                try SeedService.seedIfNeeded(context: modelContext)
                try DataMaintenanceService.prepareActiveSessions(context: modelContext)
            } catch {
                seedError = error.localizedDescription
            }
        }
        .alert("Не удалось подготовить данные", isPresented: Binding(
            get: { seedError != nil },
            set: { if !$0 { seedError = nil } }
        )) {
            Button("Закрыть", role: .cancel) { seedError = nil }
        } message: {
            Text(seedError ?? "Неизвестная ошибка")
        }
        .alert(item: Binding(
            get: { errorCenter.issue },
            set: { errorCenter.issue = $0 }
        )) { issue in
            Alert(
                title: Text(issue.title),
                message: Text(issue.message),
                dismissButton: .default(Text("Закрыть"))
            )
        }
    }
}
