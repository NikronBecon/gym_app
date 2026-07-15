import SwiftData
import SwiftUI

@main
struct GymProgressApp: App {
    private let container: ModelContainer

    init() {
        Self.excludeLocalDataFromBackup()
        do {
            let schema = Schema([
                WorkoutTemplate.self,
                TemplateSlot.self,
                TemplateVariant.self,
                PlannedSet.self,
                ScheduledWorkout.self,
                WorkoutSession.self,
                SessionExercise.self,
                SetRecord.self,
                BodyWeightEntry.self,
                AppSettings.self
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("-UITesting")
            )
            container = try ModelContainer(for: schema, configurations: configuration)
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
