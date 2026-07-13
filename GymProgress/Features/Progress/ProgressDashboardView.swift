import Charts
import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Query private var sessions: [WorkoutSession]
    @Query(sort: \BodyWeightEntry.day) private var weights: [BodyWeightEntry]
    @State private var selectedExerciseID = ExerciseCatalog.shared.items.first?.id ?? ""

    private var completed: [WorkoutSession] {
        sessions
            .filter { $0.status == .completed }
            .sorted { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) }
    }

    private var totalDuration: TimeInterval {
        completed.reduce(0) { $0 + $1.duration }
    }

    private var exercisePoints: [ExerciseProgressPoint] {
        completed.compactMap { session in
            let sets = session.exercises
                .filter { $0.catalogID == selectedExerciseID }
                .flatMap(\.sets)
                .filter(\.isCompleted)
                .compactMap { set -> (Double, Int)? in
                    guard let load = set.actualLoadTenths, let reps = set.actualReps else { return nil }
                    return (set.unit.kilograms(loadTenths: load), reps)
                }
            guard let best = sets.max(by: { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }) else { return nil }
            return ExerciseProgressPoint(
                date: session.endedAt ?? session.startedAt,
                loadKg: best.0,
                reps: best.1
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summary
                    volumeChart
                    exerciseChart
                    bodyWeightChart
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Прогресс")
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            metric(value: "\(completed.count)", label: "тренировок", icon: "checkmark.circle.fill")
            metric(
                value: durationText(totalDuration),
                label: "в зале",
                icon: "clock.fill"
            )
        }
    }

    private func metric(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(AppTheme.accent)
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration) / 60)
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    private var volumeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Объём тренировок")
                .font(.headline)
            if completed.isEmpty {
                emptyState("Появится после первой тренировки")
            } else {
                Chart(completed) { session in
                    BarMark(
                        x: .value("Дата", session.endedAt ?? session.startedAt, unit: .day),
                        y: .value("Килограммы", AnalyticsService.volumeKg(for: session))
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 190)
                .chartYAxisLabel("кг")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var exerciseChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Лучший подход")
                    .font(.headline)
                Spacer()
                Picker("Упражнение", selection: $selectedExerciseID) {
                    ForEach(ExerciseCatalog.shared.items) { Text($0.name).tag($0.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
            }
            if exercisePoints.isEmpty {
                emptyState("Нет выполненных подходов")
            } else {
                if let best = AnalyticsService.bestSet(catalogID: selectedExerciseID, sessions: completed) {
                    Text("Рекорд: \(best.loadKg.formatted(.number.precision(.fractionLength(0...1)))) кг × \(best.reps)")
                        .font(.subheadline.weight(.semibold))
                }
                Chart(exercisePoints) { point in
                    LineMark(
                        x: .value("Дата", point.date),
                        y: .value("Вес", point.loadKg)
                    )
                    .foregroundStyle(AppTheme.success)
                    PointMark(
                        x: .value("Дата", point.date),
                        y: .value("Вес", point.loadKg)
                    )
                    .foregroundStyle(AppTheme.success)
                }
                .frame(height: 190)
                .chartYAxisLabel("кг")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var bodyWeightChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Вес тела")
                .font(.headline)
            if weights.isEmpty {
                emptyState("Укажите вес при завершении тренировки")
            } else {
                Chart(weights) { entry in
                    LineMark(
                        x: .value("Дата", entry.day),
                        y: .value("Вес", Double(entry.weightTenthsKg) / 10)
                    )
                    .foregroundStyle(AppTheme.accent)
                    PointMark(
                        x: .value("Дата", entry.day),
                        y: .value("Вес", Double(entry.weightTenthsKg) / 10)
                    )
                    .foregroundStyle(AppTheme.accent)
                }
                .frame(height: 190)
                .chartYAxisLabel("кг")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 90)
    }
}

private struct ExerciseProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let loadKg: Double
    let reps: Int
}
