import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var order: Int
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var slots: [TemplateSlot]

    init(id: UUID = UUID(), name: String, order: Int, slots: [TemplateSlot] = []) {
        self.id = id
        self.name = name
        self.order = order
        self.createdAt = .now
        self.slots = slots
    }

    var sortedSlots: [TemplateSlot] { slots.sorted { $0.order < $1.order } }
}

@Model
final class TemplateSlot {
    @Attribute(.unique) var id: UUID
    var order: Int
    @Relationship(deleteRule: .cascade) var variants: [TemplateVariant]

    init(id: UUID = UUID(), order: Int, variants: [TemplateVariant] = []) {
        self.id = id
        self.order = order
        self.variants = variants
    }
}

@Model
final class TemplateVariant {
    @Attribute(.unique) var id: UUID
    var catalogID: String
    var restSeconds: Int
    @Relationship(deleteRule: .cascade) var plannedSets: [PlannedSet]

    init(
        id: UUID = UUID(),
        catalogID: String,
        restSeconds: Int = 90,
        plannedSets: [PlannedSet] = []
    ) {
        self.id = id
        self.catalogID = catalogID
        self.restSeconds = restSeconds
        self.plannedSets = plannedSets
    }

    var sortedSets: [PlannedSet] { plannedSets.sorted { $0.order < $1.order } }
}

@Model
final class PlannedSet {
    @Attribute(.unique) var id: UUID
    var order: Int
    var loadTenths: Int?
    var reps: Int?
    var unitRaw: String

    init(
        id: UUID = UUID(),
        order: Int,
        loadTenths: Int?,
        reps: Int?,
        unit: WeightUnit
    ) {
        self.id = id
        self.order = order
        self.loadTenths = loadTenths
        self.reps = reps
        self.unitRaw = unit.rawValue
    }

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }
}

@Model
final class ScheduledWorkout {
    @Attribute(.unique) var id: UUID
    var templateID: UUID
    var templateName: String
    var scheduledAt: Date
    var reminderMinutes: Int?
    var statusRaw: String
    var sessionID: UUID?

    init(
        id: UUID = UUID(),
        templateID: UUID,
        templateName: String,
        scheduledAt: Date,
        reminderMinutes: Int? = 120
    ) {
        self.id = id
        self.templateID = templateID
        self.templateName = templateName
        self.scheduledAt = scheduledAt
        self.reminderMinutes = reminderMinutes
        self.statusRaw = ScheduleStatus.planned.rawValue
    }

    var status: ScheduleStatus {
        get { ScheduleStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var templateID: UUID?
    var scheduledWorkoutID: UUID?
    var name: String
    var startedAt: Date
    var endedAt: Date?
    var statusRaw: String
    var calories: Int?
    var note: String
    var restEndDate: Date?
    @Relationship(deleteRule: .cascade) var exercises: [SessionExercise]

    init(
        id: UUID = UUID(),
        templateID: UUID?,
        scheduledWorkoutID: UUID?,
        name: String,
        startedAt: Date = .now,
        exercises: [SessionExercise] = []
    ) {
        self.id = id
        self.templateID = templateID
        self.scheduledWorkoutID = scheduledWorkoutID
        self.name = name
        self.startedAt = startedAt
        self.statusRaw = WorkoutStatus.active.rawValue
        self.note = ""
        self.exercises = exercises
    }

    var status: WorkoutStatus {
        get { WorkoutStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var sortedExercises: [SessionExercise] { exercises.sorted { $0.order < $1.order } }
    var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }
}

@Model
final class SessionExercise {
    static let sessionOnlyMarker = -1

    @Attribute(.unique) var id: UUID
    var catalogID: String
    var nameSnapshot: String
    var order: Int
    var restSeconds: Int
    var loadModeRaw: String
    @Relationship(deleteRule: .cascade) var sets: [SetRecord]

    init(
        id: UUID = UUID(),
        catalogID: String,
        nameSnapshot: String,
        order: Int,
        restSeconds: Int,
        loadMode: LoadMode,
        sets: [SetRecord] = []
    ) {
        self.id = id
        self.catalogID = catalogID
        self.nameSnapshot = nameSnapshot
        self.order = order
        self.restSeconds = restSeconds
        self.loadModeRaw = loadMode.rawValue
        self.sets = sets
    }

    var loadMode: LoadMode { LoadMode(rawValue: loadModeRaw) ?? .total }
    var sortedSets: [SetRecord] { sets.sorted { $0.order < $1.order } }

    /// Uses the retired rest-timer field as a compatibility marker so this
    /// update doesn't change the on-device schema. New schema versions can
    /// replace it with a dedicated attribute through an explicit migration.
    var isSessionOnly: Bool {
        get { restSeconds == Self.sessionOnlyMarker }
        set {
            if newValue {
                restSeconds = Self.sessionOnlyMarker
            } else if restSeconds == Self.sessionOnlyMarker {
                restSeconds = 0
            }
        }
    }
}

@Model
final class SetRecord {
    @Attribute(.unique) var id: UUID
    var order: Int
    var plannedLoadTenths: Int?
    var plannedReps: Int?
    var actualLoadTenths: Int?
    var actualReps: Int?
    var unitRaw: String
    var isCompleted: Bool
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        order: Int,
        plannedLoadTenths: Int?,
        plannedReps: Int?,
        actualLoadTenths: Int?,
        actualReps: Int?,
        unit: WeightUnit
    ) {
        self.id = id
        self.order = order
        self.plannedLoadTenths = plannedLoadTenths
        self.plannedReps = plannedReps
        self.actualLoadTenths = actualLoadTenths
        self.actualReps = actualReps
        self.unitRaw = unit.rawValue
        self.isCompleted = false
    }

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }
}

@Model
final class BodyWeightEntry {
    @Attribute(.unique) var id: UUID
    var day: Date
    var weightTenthsKg: Int

    init(id: UUID = UUID(), day: Date, weightTenthsKg: Int) {
        self.id = id
        self.day = Calendar.current.startOfDay(for: day)
        self.weightTenthsKg = weightTenthsKg
    }
}

@Model
final class AppSettings {
    @Attribute(.unique) var id: String
    var seedVersion: Int

    init(id: String = "main", seedVersion: Int = 0) {
        self.id = id
        self.seedVersion = seedVersion
    }
}
