import Foundation

enum AnalyticsService {
    static func volumeKg(for session: WorkoutSession) -> Double {
        session.exercises.reduce(0) { total, exercise in
            guard exercise.loadMode != .bodyweight else { return total }
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
        var best: (loadKg: Double, reps: Int)?

        for session in sessions where session.status == .completed {
            for exercise in session.exercises
                where exercise.catalogID == catalogID && exercise.loadMode != .bodyweight {
                for set in exercise.sets where set.isCompleted {
                    guard let load = set.actualLoadTenths, let reps = set.actualReps else { continue }

                    let candidate = (loadKg: set.unit.kilograms(loadTenths: load), reps: reps)
                    guard let current = best else {
                        best = candidate
                        continue
                    }

                    if candidate.loadKg > current.loadKg
                        || (candidate.loadKg == current.loadKg && candidate.reps > current.reps) {
                        best = candidate
                    }
                }
            }
        }

        return best
    }
}
