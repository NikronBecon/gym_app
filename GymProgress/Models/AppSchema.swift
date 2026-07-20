import SwiftData

/// The persisted model shipped before explicit schema versioning was adopted.
/// Keep this definition unchanged. Future model changes belong in V2 together
/// with a migration stage in `GymProgressMigrationPlan`.
enum GymProgressSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
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
        ]
    }
}

enum GymProgressMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GymProgressSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
