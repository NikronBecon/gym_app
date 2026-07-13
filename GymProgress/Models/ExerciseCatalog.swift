import Foundation

struct ExerciseCatalogItem: Codable, Identifiable, Hashable {
    let id: String
    let sourceName: String
    let name: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let equipment: String
    let gifName: String
    let attribution: String
    let technique: [String]
    let loadMode: LoadMode
    let defaultUnit: WeightUnit
}

final class ExerciseCatalog {
    static let shared = ExerciseCatalog()

    let items: [ExerciseCatalogItem]
    private let byID: [String: ExerciseCatalogItem]

    private init(bundle: Bundle = .main) {
        let nestedURL = bundle.url(
            forResource: "exercises",
            withExtension: "json",
            subdirectory: "Resources"
        )
        let rootURL = bundle.url(forResource: "exercises", withExtension: "json")
        guard let url = nestedURL ?? rootURL,
        let data = try? Data(contentsOf: url),
        let decoded = try? JSONDecoder().decode([ExerciseCatalogItem].self, from: data)
        else {
            items = []
            byID = [:]
            return
        }
        items = decoded.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        byID = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    func item(id: String) -> ExerciseCatalogItem? { byID[id] }
}
