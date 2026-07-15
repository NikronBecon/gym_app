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
        let completed = try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == "completed" },
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        ))

        let exercises = template.sortedSlots.enumerated().compactMap { index, slot -> SessionExercise? in
            let selected = choices[slot.id].flatMap { choice in
                slot.variants.first { $0.id == choice }
            } ?? slot.variants.first
            guard let selected else { return nil }

            let catalogItem = ExerciseCatalog.shared.item(id: selected.catalogID)
            let previous = completed.lazy
                .flatMap(\.exercises)
                .first {
                    $0.catalogID == selected.catalogID
                        && $0.sets.contains(where: \.isCompleted)
                }

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
            let scheduleID = scheduledWorkoutID
            let descriptor = FetchDescriptor<ScheduledWorkout>(
                predicate: #Predicate { $0.id == scheduleID }
            )
            if let schedule = try context.fetch(descriptor).first {
                schedule.sessionID = session.id
                schedule.status = .inProgress
                NotificationService.cancel(workoutID: schedule.id)
            }
        }

        try context.save()
        return session
    }
}
