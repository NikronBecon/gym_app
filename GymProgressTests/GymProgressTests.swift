import Foundation
import SwiftData
import Testing
@testable import GymProgress

struct GymProgressTests {
    @Test func catalogContainsOneHundredLocalizedExercises() {
        #expect(ExerciseCatalog.shared.items.count == 100)
        #expect(ExerciseCatalog.shared.items.allSatisfy {
            $0.name.range(of: "[A-Za-z]", options: .regularExpression) == nil
        })
        #expect(ExerciseCatalog.shared.items.allSatisfy { item in
            (item.primaryMuscles + item.secondaryMuscles + [item.equipment] + item.technique).allSatisfy {
                $0.range(of: "[A-Za-z]", options: .regularExpression) == nil
            }
        })
    }

    @Test func poundsConvertToKilograms() {
        let value = WeightUnit.lb.kilograms(loadTenths: 1_000)
        #expect(abs(value - 45.359237) < 0.000_001)
    }

    @Test func changingWeightUnitPreservesPhysicalWeight() {
        let pounds = WeightUnit.kg.converted(loadTenths: 1_000, to: .lb)
        let kilograms = WeightUnit.lb.converted(loadTenths: pounds, to: .kg)

        #expect(pounds == 2_205)
        #expect(abs(kilograms - 1_000) <= 1)
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

    @Test func weightedBodyweightExerciseCountsAdditionalLoad() {
        let set = SetRecord(
            order: 0,
            plannedLoadTenths: 200,
            plannedReps: 5,
            actualLoadTenths: 200,
            actualReps: 5,
            unit: .kg
        )
        set.isCompleted = true
        let exercise = SessionExercise(
            catalogID: "0652",
            nameSnapshot: "Подтягивания",
            order: 0,
            restSeconds: 90,
            loadMode: .additionalBodyweight,
            sets: [set]
        )
        let session = WorkoutSession(
            templateID: nil,
            scheduledWorkoutID: nil,
            name: "Тест",
            exercises: [exercise]
        )

        #expect(AnalyticsService.volumeKg(for: session) == 100)
    }

    @Test func volumeIgnoresUnfinishedSets() {
        let set = SetRecord(
            order: 0,
            plannedLoadTenths: 1_000,
            plannedReps: 10,
            actualLoadTenths: 1_000,
            actualReps: 10,
            unit: .kg
        )
        let exercise = SessionExercise(
            catalogID: "0025",
            nameSnapshot: "Жим",
            order: 0,
            restSeconds: 90,
            loadMode: .total,
            sets: [set]
        )
        let session = WorkoutSession(
            templateID: nil,
            scheduledWorkoutID: nil,
            name: "Тест",
            exercises: [exercise]
        )

        #expect(AnalyticsService.volumeKg(for: session) == 0)
    }

    @Test func bestSetUsesRepetitionsAsTieBreaker() {
        let first = SetRecord(
            order: 0,
            plannedLoadTenths: 1_000,
            plannedReps: 5,
            actualLoadTenths: 1_000,
            actualReps: 5,
            unit: .kg
        )
        let second = SetRecord(
            order: 1,
            plannedLoadTenths: 1_000,
            plannedReps: 8,
            actualLoadTenths: 1_000,
            actualReps: 8,
            unit: .kg
        )
        first.isCompleted = true
        second.isCompleted = true
        let exercise = SessionExercise(
            catalogID: "0025",
            nameSnapshot: "Жим",
            order: 0,
            restSeconds: 90,
            loadMode: .total,
            sets: [first, second]
        )
        let session = WorkoutSession(
            templateID: nil,
            scheduledWorkoutID: nil,
            name: "Тест",
            exercises: [exercise]
        )
        session.status = .completed

        let best = AnalyticsService.bestSet(catalogID: "0025", sessions: [session])
        #expect(best?.loadKg == 100)
        #expect(best?.reps == 8)
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
        let context = try makeContext()

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

    @MainActor
    @Test func scheduledWorkoutBecomesInProgressWhenStarted() throws {
        let context = try makeContext()
        let variant = TemplateVariant(
            catalogID: "0025",
            plannedSets: [PlannedSet(order: 0, loadTenths: 500, reps: 8, unit: .kg)]
        )
        let template = WorkoutTemplate(
            name: "Тест",
            order: 0,
            slots: [TemplateSlot(order: 0, variants: [variant])]
        )
        let schedule = ScheduledWorkout(
            templateID: template.id,
            templateName: template.name,
            scheduledAt: .now
        )
        context.insert(template)
        context.insert(schedule)

        let session = try WorkoutBuilder.start(
            template: template,
            choices: [:],
            scheduledWorkoutID: schedule.id,
            context: context
        )

        #expect(schedule.status == .inProgress)
        #expect(schedule.sessionID == session.id)
    }

    @MainActor
    @Test func workoutUsesLastActuallyCompletedExerciseAsReference() throws {
        let context = try makeContext()
        let olderSet = SetRecord(
            order: 0,
            plannedLoadTenths: 700,
            plannedReps: 8,
            actualLoadTenths: 700,
            actualReps: 8,
            unit: .kg
        )
        olderSet.isCompleted = true
        let olderExercise = SessionExercise(
            catalogID: "0025",
            nameSnapshot: "Жим",
            order: 0,
            restSeconds: 90,
            loadMode: .total,
            sets: [olderSet]
        )
        let olderSession = WorkoutSession(
            templateID: nil,
            scheduledWorkoutID: nil,
            name: "Старая",
            startedAt: .now.addingTimeInterval(-7_200),
            exercises: [olderExercise]
        )
        olderSession.status = .completed
        olderSession.endedAt = .now.addingTimeInterval(-7_000)

        let skippedSet = SetRecord(
            order: 0,
            plannedLoadTenths: 900,
            plannedReps: 5,
            actualLoadTenths: 900,
            actualReps: 5,
            unit: .kg
        )
        let skippedExercise = SessionExercise(
            catalogID: "0025",
            nameSnapshot: "Жим",
            order: 0,
            restSeconds: 90,
            loadMode: .total,
            sets: [skippedSet]
        )
        let newerSession = WorkoutSession(
            templateID: nil,
            scheduledWorkoutID: nil,
            name: "Новая",
            startedAt: .now.addingTimeInterval(-3_600),
            exercises: [skippedExercise]
        )
        newerSession.status = .completed
        newerSession.endedAt = .now.addingTimeInterval(-3_400)

        let planned = PlannedSet(order: 0, loadTenths: 500, reps: 10, unit: .kg)
        let variant = TemplateVariant(catalogID: "0025", plannedSets: [planned])
        let template = WorkoutTemplate(
            name: "Следующая",
            order: 0,
            slots: [TemplateSlot(order: 0, variants: [variant])]
        )
        context.insert(olderSession)
        context.insert(newerSession)
        context.insert(template)

        let session = try WorkoutBuilder.start(
            template: template,
            choices: [:],
            scheduledWorkoutID: nil,
            context: context
        )

        #expect(session.exercises.first?.sets.first?.plannedLoadTenths == 700)
        #expect(session.exercises.first?.sets.first?.plannedReps == 8)
    }

    @MainActor
    @Test func deletingTemplateRemovesOnlyItsPlannedSchedules() throws {
        let context = try makeContext()
        let template = WorkoutTemplate(name: "Удаляемый", order: 0)
        let planned = ScheduledWorkout(
            templateID: template.id,
            templateName: template.name,
            scheduledAt: .now
        )
        let completed = ScheduledWorkout(
            templateID: template.id,
            templateName: template.name,
            scheduledAt: .now
        )
        completed.status = .completed
        let history = WorkoutSession(
            templateID: template.id,
            scheduledWorkoutID: completed.id,
            name: template.name
        )
        history.status = .completed
        history.endedAt = .now
        context.insert(template)
        context.insert(planned)
        context.insert(completed)
        context.insert(history)
        try context.save()

        try TemplateService.delete([template], context: context)

        let schedules = try context.fetch(FetchDescriptor<ScheduledWorkout>())
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(schedules.count == 1)
        #expect(schedules.first?.id == completed.id)
        #expect(sessions.count == 1)
        #expect(sessions.first?.id == history.id)
    }

    @MainActor
    @Test func templateDeletionRemovesPendingExerciseButKeepsSessionOnlyExercise() throws {
        let context = try makeContext()
        let first = TemplateVariant(
            catalogID: "0025",
            plannedSets: [PlannedSet(order: 0, loadTenths: 500, reps: 8, unit: .kg)]
        )
        let removed = TemplateVariant(
            catalogID: "0652",
            plannedSets: [PlannedSet(order: 0, loadTenths: nil, reps: 8, unit: .kg)]
        )
        let removedSlot = TemplateSlot(order: 1, variants: [removed])
        let template = WorkoutTemplate(
            name: "Тест",
            order: 0,
            slots: [TemplateSlot(order: 0, variants: [first]), removedSlot]
        )
        context.insert(template)
        let session = try WorkoutBuilder.start(
            template: template,
            choices: [:],
            scheduledWorkoutID: nil,
            context: context
        )
        session.exercises.append(SessionExercise(
            catalogID: "0334",
            nameSnapshot: "Махи гантелями в стороны",
            order: 2,
            restSeconds: SessionExercise.sessionOnlyMarker,
            loadMode: .perHand,
            sets: [SetRecord(
                order: 0,
                plannedLoadTenths: nil,
                plannedReps: nil,
                actualLoadTenths: nil,
                actualReps: nil,
                unit: .kg
            )]
        ))
        template.slots.removeAll { $0.id == removedSlot.id }
        context.delete(removedSlot)

        TemplateService.sync(
            for: template,
            context: context,
            errors: AppErrorCenter()
        )

        #expect(session.exercises.contains(where: { $0.catalogID == "0025" }))
        #expect(!session.exercises.contains(where: { $0.catalogID == "0652" }))
        #expect(session.exercises.contains(where: { $0.catalogID == "0334" }))
    }

    @MainActor
    @Test func reducingTemplateSetsRemovesOnlyPendingExtras() throws {
        let context = try makeContext()
        let plannedSets = (0..<3).map {
            PlannedSet(order: $0, loadTenths: 500, reps: 8, unit: .kg)
        }
        let variant = TemplateVariant(catalogID: "0025", plannedSets: plannedSets)
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
        let completedExtra = session.exercises[0].sortedSets[2]
        completedExtra.isCompleted = true

        for set in variant.sortedSets.dropFirst() {
            variant.plannedSets.removeAll { $0.id == set.id }
            context.delete(set)
        }
        TemplateService.sync(
            for: template,
            context: context,
            errors: AppErrorCenter()
        )

        #expect(session.exercises[0].sets.count == 2)
        #expect(session.exercises[0].sets.contains(where: { $0.id == completedExtra.id }))
    }

    @MainActor
    @Test func versionedContainerOpensExistingUnversionedStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymProgressMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")

        do {
            let legacySchema = Schema(GymProgressSchemaV1.models)
            let legacyConfiguration = ModelConfiguration(
                "MigrationTest",
                schema: legacySchema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let legacyContainer = try ModelContainer(
                for: legacySchema,
                configurations: legacyConfiguration
            )
            let legacyContext = ModelContext(legacyContainer)
            legacyContext.insert(WorkoutTemplate(name: "Сохранённый шаблон", order: 0))
            try legacyContext.save()
        }

        let versionedSchema = Schema(versionedSchema: GymProgressSchemaV1.self)
        let versionedConfiguration = ModelConfiguration(
            "MigrationTest",
            schema: versionedSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let versionedContainer = try ModelContainer(
            for: versionedSchema,
            migrationPlan: GymProgressMigrationPlan.self,
            configurations: versionedConfiguration
        )
        let versionedContext = ModelContext(versionedContainer)
        let templates = try versionedContext.fetch(FetchDescriptor<WorkoutTemplate>())

        #expect(templates.map(\.name) == ["Сохранённый шаблон"])
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
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
        return ModelContext(container)
    }
}
