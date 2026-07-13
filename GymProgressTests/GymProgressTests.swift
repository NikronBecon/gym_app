import SwiftData
import Testing
@testable import GymProgress

struct GymProgressTests {
    @Test func poundsConvertToKilograms() {
        let value = WeightUnit.lb.kilograms(loadTenths: 1_000)
        #expect(abs(value - 45.359237) < 0.000_001)
    }

    @Test func dumbbellVolumeCountsBothHands() {
        let set = SetRecord(
            order: 0,
            plannedLoadTenths: 140,
            plannedReps: 10,
            actualLoadTenths: 140,
            actualReps: 10,
            unit: .kg
        )
        set.isCompleted = true
        let exercise = SessionExercise(
            catalogID: "0313",
            nameSnapshot: "Молотковые сгибания",
            order: 0,
            restSeconds: 90,
            loadMode: .perHand,
            sets: [set]
        )
        let session = WorkoutSession(
            templateID: nil,
            scheduledWorkoutID: nil,
            name: "Тест",
            exercises: [exercise]
        )
        session.status = .completed

        #expect(AnalyticsService.volumeKg(for: session) == 280)
    }

    @MainActor
    @Test func seedIsIdempotent() throws {
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        try SeedService.seedIfNeeded(context: context)
        try SeedService.seedIfNeeded(context: context)

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(templates.count == 3)
    }

    @MainActor
    @Test func workoutIsSnapshotOfTemplate() throws {
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let planned = PlannedSet(order: 0, loadTenths: 600, reps: 8, unit: .kg)
        let variant = TemplateVariant(catalogID: "0025", plannedSets: [planned])
        let template = WorkoutTemplate(
            name: "Тест",
            order: 0,
            slots: [TemplateSlot(order: 0, variants: [variant])]
        )
        context.insert(template)

        let session = try WorkoutBuilder.start(
            template: template,
            choices: [:],
            scheduledWorkoutID: nil,
            context: context
        )
        planned.loadTenths = 700

        #expect(session.exercises.first?.sets.first?.plannedLoadTenths == 600)
    }
}
