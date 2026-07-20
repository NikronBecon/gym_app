import Foundation
import SwiftData

@MainActor
enum DataMaintenanceService {
    /// Marks exercises that were manually added to an already active workout
    /// before the app started storing that distinction. The pass is
    /// conservative: unmatched legacy exercises are preserved as session-only
    /// instead of risking deletion of entered workout data.
    static func prepareActiveSessions(context: ModelContext) throws {
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == "active" }
        ))
        let templatesByID = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })

        for session in sessions {
            guard let templateID = session.templateID,
                  let template = templatesByID[templateID] else {
                session.exercises.forEach { $0.isSessionOnly = true }
                continue
            }

            var matchedExerciseIDs = Set<UUID>()
            for slot in template.sortedSlots {
                let selected = slot.variants.first { variant in
                    session.exercises.contains(where: { $0.catalogID == variant.catalogID })
                } ?? slot.variants.first
                guard let selected,
                      let exercise = session.sortedExercises.first(where: {
                          !matchedExerciseIDs.contains($0.id) && $0.catalogID == selected.catalogID
                      }) else { continue }
                matchedExerciseIDs.insert(exercise.id)
            }

            for exercise in session.exercises where !matchedExerciseIDs.contains(exercise.id) {
                exercise.isSessionOnly = true
            }
        }

        try context.save()
    }
}
