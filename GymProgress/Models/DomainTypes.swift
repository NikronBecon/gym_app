import Foundation

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kg
    case lb

    var id: String { rawValue }

    func kilograms(loadTenths: Int) -> Double {
        let value = Double(loadTenths) / 10
        return self == .kg ? value : value * 0.45359237
    }

    func converted(loadTenths: Int, to target: WeightUnit) -> Int {
        guard self != target else { return loadTenths }
        let kilograms = kilograms(loadTenths: loadTenths)
        let value = target == .kg ? kilograms : kilograms / 0.45359237
        return Int((value * 10).rounded())
    }
}

enum LoadMode: String, Codable {
    case total
    case perHand
    case bodyweight
    case additionalBodyweight
}

enum WorkoutStatus: String, Codable {
    case active
    case completed
    case discarded
}

enum ScheduleStatus: String, Codable {
    case planned
    case inProgress
    case completed
    case skipped
}

extension Int {
    var loadText: String {
        let value = Double(self) / 10
        return value.rounded() == value
            ? String(Int(value))
            : value.formatted(.number.precision(.fractionLength(1)))
    }
}
