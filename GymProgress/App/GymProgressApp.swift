import SwiftData
import SwiftUI

@main
struct GymProgressApp: App {
    private let container: ModelContainer

    init() {
        Self.excludeLocalDataFromBackup()
        do {
            container = try ModelContainer(
                for: WorkoutTemplate.self,
                TemplateSlot.self,
                TemplateVariant.self,
                PlannedSet.self,
                ScheduledWorkout.self,
                WorkoutSession.self,
                SessionExercise.self,
                SetRecord.self,
                BodyWeightEntry.self,
                AppSettings.self
            )
        } catch {
            fatalError("Не удалось открыть локальную базу: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }

    private static func excludeLocalDataFromBackup() {
        guard let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return }

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(values)
    }
}
