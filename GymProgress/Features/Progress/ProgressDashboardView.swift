import Charts
import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.statusRaw == "completed" },
        sort: \WorkoutSession.startedAt
    ) private var sessions: [WorkoutSession]
    @Query(sort: \BodyWeightEntry.day) private var weights: [BodyWeightEntry]
    @State private var selectedExerciseID: String?

    private var completed: [WorkoutSession] {
        sessions
    }

    private var totalDuration: TimeInterval {
        completed.reduce(0) { $0 + $1.duration }
    }

    private var bodyWeightValues: [Double] {
        weights.map { Double($0.weightTenthsKg) / 10 }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let workoutDays = Set(completed.map { calendar.startOfDay(for: $0.endedAt ?? $0.startedAt) })
        guard !workoutDays.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: .now)
        if !workoutDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), workoutDays.contains(yesterday) else {
                return 0
            }
            day = yesterday
        }

        var streak = 0
        while workoutDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }
        return streak
    }

    private var displayedSessions: [WorkoutSession] {
        let performed = completed.reversed().filter { session in
            session.exercises.contains { $0.sets.contains(where: \.isCompleted) }
        }
        guard let selectedExerciseID else { return performed }
        return performed.filter { session in
            session.exercises.contains {
                $0.catalogID == selectedExerciseID && $0.sets.contains(where: \.isCompleted)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summary
                    bodyWeightChart
                    historySection
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Прогресс")
        }
    }

    private var summary: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            metric(value: "\(completed.count)", label: "тренировок", icon: "checkmark.circle.fill")
            metric(
                value: durationText(totalDuration),
                label: "в зале",
                icon: "clock.fill"
            )
            metric(
                value: "\(currentStreak)",
                label: "дней подряд",
                icon: "flame.fill"
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
                .chartYScale(domain: chartDomain(for: bodyWeightValues))
                .chartXAxis { dateAxis }
                .chartXScale(domain: dateDomain(for: weights.map(\.day)))
                .chartXAxisLabel("Дата", position: .bottom)
                .chartYAxis { bodyWeightAxis }
                .chartYAxisLabel("Вес, кг", position: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("История тренировок")
                    .font(.headline)
                Spacer()
                Picker("Упражнение", selection: $selectedExerciseID) {
                    Text("Все").tag(String?.none)
                    ForEach(ExerciseCatalog.shared.items) { item in
                        Text(item.name).tag(Optional(item.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            Text("Здесь показаны только упражнения и подходы, которые были отмечены выполненными.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            if displayedSessions.isEmpty {
                emptyState(selectedExerciseID == nil
                    ? "Завершённые тренировки появятся здесь"
                    : "Нет выполненных подходов для этого упражнения")
            } else {
                ForEach(displayedSessions) { session in
                    NavigationLink {
                        WorkoutHistoryDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(session.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Text((session.endedAt ?? session.startedAt).formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Text("\(completedExerciseCount(in: session)) упражнений · \(completedSetCount(in: session)) подходов")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func completedSetCount(in session: WorkoutSession) -> Int {
        session.exercises.flatMap(\.sets).filter(\.isCompleted).count
    }

    private func completedExerciseCount(in session: WorkoutSession) -> Int {
        session.exercises.filter { $0.sets.contains(where: \.isCompleted) }.count
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 90)
    }

    @AxisContentBuilder
    private var dateAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.gray.opacity(0.35))
            AxisTick()
            AxisValueLabel(format: .dateTime.day().month())
        }
    }

    @AxisContentBuilder
    private var bodyWeightAxis: some AxisContent {
        AxisMarks(position: .leading) { _ in
            AxisGridLine()
                .foregroundStyle(.gray.opacity(0.25))
            AxisTick()
            AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
        }
    }

    private func chartDomain(for values: [Double], startsAtZero: Bool = false) -> ClosedRange<Double> {
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        let span = max(maximum - minimum, max(abs(maximum) * 0.1, 1))
        let lower = startsAtZero ? 0 : minimum - span * 0.15
        let upper = maximum + span * 0.15
        return lower...max(upper, lower + 1)
    }

    private func dateDomain(for dates: [Date]) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let first = dates.min() ?? .now
        let last = dates.max() ?? first
        let padding = dates.count == 1 ? 3 : 1
        let start = calendar.date(byAdding: .day, value: -padding, to: first)!
        let end = calendar.date(byAdding: .day, value: padding, to: last)!
        return start...end
    }
}

private struct WorkoutHistoryDetailView: View {
    let session: WorkoutSession

    private var completedExercises: [SessionExercise] {
        session.sortedExercises.filter { $0.sets.contains(where: \.isCompleted) }
    }

    var body: some View {
        List {
            Section("Тренировка") {
                LabeledContent("Дата", value: (session.endedAt ?? session.startedAt).formatted(date: .long, time: .shortened))
                LabeledContent("Длительность", value: durationText)
            }

            ForEach(completedExercises) { exercise in
                Section(exercise.nameSnapshot) {
                    ForEach(exercise.sortedSets.filter(\.isCompleted)) { set in
                        HStack {
                            Text("Подход \(set.order + 1)")
                            Spacer()
                            Text(setSummary(set, loadMode: exercise.loadMode))
                                .foregroundStyle(.primary)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var durationText: String {
        let seconds = max(0, Int(session.duration))
        return String(format: "%d:%02d", seconds / 3_600, (seconds % 3_600) / 60)
    }

    private func setSummary(_ set: SetRecord, loadMode: LoadMode) -> String {
        let reps = set.actualReps.map(String.init) ?? "—"
        guard loadMode != .bodyweight else { return "свой вес × \(reps)" }
        let weight = set.actualLoadTenths.map { "\($0.loadText) \(set.unit.rawValue)" } ?? "—"
        return "\(weight) × \(reps)"
    }
}
