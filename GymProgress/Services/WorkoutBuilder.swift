import Foundation
import SwiftData

@MainActor
enum WorkoutBuilder {
    static func start(
        template: WorkoutTemplate,
        choices: [UUID: UUID],
        scheduledWorkoutID: UUID?,
        context: ModelContext
    ) throws -> WorkoutSession {
        let completed = try context.fetch(FetchDescriptor<WorkoutSession>())
            .filter { $0.status == .completed }
            .sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }

        let exercises = template.sortedSlots.enumerated().compactMap { index, slot -> SessionExercise? in
            let selected = choices[slot.id].flatMap { choice in
                slot.variants.first { $0.id == choice }
            } ?? slot.variants.first
            guard let selected else { return nil }

            let catalogItem = ExerciseCatalog.shared.item(id: selected.catalogID)
            let previous = completed.lazy
                .flatMap(\.exercises)
                .first { $0.catalogID == selected.catalogID }

            let previousSets: [(Int?, Int?, WeightUnit)] = previous?.sortedSets
                    .filter(\.isCompleted)
                    .map { ($0.actualLoadTenths, $0.actualReps, $0.unit) }
                ?? []
            let sourceSets: [(Int?, Int?, WeightUnit)]
            if previousSets.isEmpty {
                sourceSets = selected.sortedSets.map { ($0.loadTenths, $0.reps, $0.unit) }
            } else {
                sourceSets = previousSets
            }

            let records = sourceSets.enumerated().map { setIndex, value in
                SetRecord(
                    order: setIndex,
                    plannedLoadTenths: value.0,
                    plannedReps: value.1,
                    actualLoadTenths: value.0,
                    actualReps: value.1,
                    unit: value.2
                )
            }

            return SessionExercise(
                catalogID: selected.catalogID,
                nameSnapshot: catalogItem?.name ?? selected.catalogID,
                order: index,
                restSeconds: selected.restSeconds,
                loadMode: catalogItem?.loadMode ?? .total,
                sets: records
            )
        }

        let session = WorkoutSession(
            templateID: template.id,
            scheduledWorkoutID: scheduledWorkoutID,
            name: template.name,
            exercises: exercises
        )
        context.insert(session)

        if let scheduledWorkoutID {
            let schedules = try context.fetch(FetchDescriptor<ScheduledWorkout>())
            schedules.first { $0.id == scheduledWorkoutID }?.sessionID = session.id
        }

        try context.save()
        return session
    }
}
