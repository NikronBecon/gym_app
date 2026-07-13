import Foundation
import SwiftData

@MainActor
enum SeedService {
    static let currentVersion = 1

    static func seedIfNeeded(context: ModelContext) throws {
        let settings = try context.fetch(FetchDescriptor<AppSettings>()).first
        if let settings, settings.seedVersion >= currentVersion { return }
        guard !ExerciseCatalog.shared.items.isEmpty else { return }

        let templates = [dayOne(), dayTwo(), dayThree()]
        templates.forEach(context.insert)

        if let settings {
            settings.seedVersion = currentVersion
        } else {
            context.insert(AppSettings(seedVersion: currentVersion))
        }
        try context.save()
    }

    private static func dayOne() -> WorkoutTemplate {
        WorkoutTemplate(name: "День 1", order: 0, slots: [
            slot(0, [variant("0025", sets: sets(.kg, [(600, 8), (600, 6), (600, 5), (600, 7)]))]),
            slot(1, [
                variant("0652", sets: sets(.kg, [(0, 8), (80, 5), (80, 4), (80, 4)])),
                variant("0861", sets: sets(.lb, [(1000, 12), (1000, 12), (1000, 9), (1000, 9)]))
            ]),
            slot(2, [variant("0405", sets: sets(.kg, [(140, 12), (140, 12), (140, 9), (140, 6)]))]),
            slot(3, [variant("0334", sets: sets(.kg, [(100, 12), (100, 12), (100, 12), (100, 12)]))]),
            slot(4, [variant("0372", sets: sets(.kg, [(60, 14), (60, 8)]))]),
            slot(5, [variant("0200", sets: blankSets(3, unit: .kg))])
        ])
    }

    private static func dayTwo() -> WorkoutTemplate {
        WorkoutTemplate(name: "День 2", order: 1, slots: [
            slot(0, [variant("1463", sets: sets(.kg, [(1200, 8), (1200, 8), (1200, 8), (1200, 8)]))]),
            slot(1, [variant("0488", sets: blankSets(3, unit: .kg))]),
            slot(2, [variant("0586", sets: sets(.kg, [(180, 12), (230, 12), (230, 12), (270, 12)]))]),
            slot(3, [variant("0585", sets: sets(.kg, [(450, 12), (450, 12), (480, 12), (480, 12)]))]),
            slot(4, [variant("0605", sets: blankSets(4, unit: .kg))]),
            slot(5, [variant("0598", sets: sets(.kg, [(320, 20), (320, 20)]))])
        ])
    }

    private static func dayThree() -> WorkoutTemplate {
        WorkoutTemplate(name: "День 3", order: 2, slots: [
            slot(0, [variant("0047", sets: sets(.kg, [(500, 8), (500, 8), (500, 8), (500, nil)]))]),
            slot(1, [variant("0861", sets: sets(.lb, [(1000, 12), (1000, 12), (1000, 12), (1000, 12)]))]),
            slot(2, [variant("0652", sets: sets(.kg, [(nil, 8), (nil, 7), (nil, 6), (nil, 6)]))]),
            slot(3, [variant("0596", sets: sets(.kg, [(450, 12), (450, 9), (450, 6), (410, 9)]))]),
            slot(4, [variant("0602", sets: sets(.kg, [(270, 12), (320, 10), (320, 10)]))]),
            slot(5, [variant("0313", sets: sets(.kg, [(140, 18), (140, 12), (140, 10), (120, 10)]))]),
            slot(6, [
                variant("0200", sets: sets(.kg, [(nil, 16), (nil, 16), (nil, 14), (nil, 10)])),
                variant("1749", sets: sets(.kg, [(25, 15), (50, 15), (nil, 10)]))
            ])
        ])
    }

    private static func slot(_ order: Int, _ variants: [TemplateVariant]) -> TemplateSlot {
        TemplateSlot(order: order, variants: variants)
    }

    private static func variant(_ catalogID: String, sets: [PlannedSet]) -> TemplateVariant {
        TemplateVariant(catalogID: catalogID, restSeconds: 90, plannedSets: sets)
    }

    private static func sets(
        _ unit: WeightUnit,
        _ values: [(Int?, Int?)]
    ) -> [PlannedSet] {
        values.enumerated().map { index, value in
            PlannedSet(order: index, loadTenths: value.0, reps: value.1, unit: unit)
        }
    }

    private static func blankSets(_ count: Int, unit: WeightUnit) -> [PlannedSet] {
        (0..<count).map { PlannedSet(order: $0, loadTenths: nil, reps: nil, unit: unit) }
    }
}
