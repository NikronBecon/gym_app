import Foundation

enum AnalyticsService {
    static func volumeKg(for session: WorkoutSession) -> Double {
        session.exercises.reduce(0) { total, exercise in
            guard exercise.loadMode != .bodyweight,
                  exercise.loadMode != .additionalBodyweight else { return total }
            let multiplier = exercise.loadMode == .perHand ? 2.0 : 1.0
            let exerciseVolume = exercise.sets.reduce(0.0) { subtotal, set in
                guard set.isCompleted,
                      let load = set.actualLoadTenths,
                      let reps = set.actualReps else { return subtotal }
                return subtotal + set.unit.kilograms(loadTenths: load) * Double(reps) * multiplier
            }
            return total + exerciseVolume
        }
    }

    static func bestSet(
        catalogID: String,
        sessions: [WorkoutSession]
    ) -> (loadKg: Double, reps: Int)? {
        sessions
            .filter { $0.status == .completed }
            .flatMap(\.exercises)
            .filter { $0.catalogID == catalogID && $0.loadMode != .bodyweight }
            .flatMap(\.sets)
            .filter(\.isCompleted)
            .compactMap { set -> (Double, Int)? in
                guard let load = set.actualLoadTenths, let reps = set.actualReps else { return nil }
                return (set.unit.kilograms(loadTenths: load), reps)
            }
            .max { left, right in
                left.0 == right.0 ? left.1 < right.1 : left.0 < right.0
            }
    }
}
