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
    @State private var weightManager: WeightManagerRequest?

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
        .sheet(item: $weightManager) { _ in
            BodyWeightManagerView()
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
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 88, alignment: .leading)
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
                emptyState("Нажмите здесь, чтобы добавить первый замер")
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
            Text("Нажмите на график, чтобы добавить или удалить замер.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .contentShape(Rectangle())
        .onTapGesture { weightManager = WeightManagerRequest() }
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

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
                        if isEditing {
                            HistorySetEditorRow(
                                set: set,
                                loadMode: exercise.loadMode,
                                onDelete: { delete(set, from: exercise) }
                            )
                        } else {
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
                    if isEditing {
                        Button("Добавить подход", systemImage: "plus") { addSet(to: exercise) }
                    }
                }
            }
        }
        .dismissKeyboardOnTap()
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isEditing {
                    Button("Удалить", systemImage: "trash", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
                Button(isEditing ? "Готово" : "Править", systemImage: isEditing ? "checkmark" : "square.and.pencil") {
                    if isEditing { try? modelContext.save() }
                    isEditing.toggle()
                }
            }
        }
        .alert("Удалить тренировку из истории?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive, action: deleteSession)
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Будут удалены тренировка, все её упражнения и подходы. Это действие нельзя отменить.")
        }
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

    private func addSet(to exercise: SessionExercise) {
        let last = exercise.sortedSets.filter(\.isCompleted).last
        let set = SetRecord(
            order: exercise.sets.count,
            plannedLoadTenths: last?.plannedLoadTenths,
            plannedReps: last?.plannedReps,
            actualLoadTenths: last?.actualLoadTenths,
            actualReps: last?.actualReps,
            unit: last?.unit ?? .kg
        )
        set.isCompleted = true
        set.completedAt = session.endedAt ?? .now
        exercise.sets.append(set)
        try? modelContext.save()
    }

    private func delete(_ set: SetRecord, from exercise: SessionExercise) {
        exercise.sets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        for (index, item) in exercise.sortedSets.enumerated() { item.order = index }
        try? modelContext.save()
    }

    private func deleteSession() {
        if let scheduledWorkoutID = session.scheduledWorkoutID {
            let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: #Predicate { $0.id == scheduledWorkoutID })
            if let scheduledWorkout = try? modelContext.fetch(descriptor).first {
                NotificationService.cancel(workoutID: scheduledWorkout.id)
                modelContext.delete(scheduledWorkout)
            }
        }
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }
}

private struct HistorySetEditorRow: View {
    @Bindable var set: SetRecord
    let loadMode: LoadMode
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Подход \(set.order + 1)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                }
                .accessibilityLabel("Удалить подход \(set.order + 1)")
            }
            HStack(spacing: 8) {
                if loadMode == .bodyweight {
                    Text("Свой вес")
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    OptionalLoadField(loadTenths: $set.actualLoadTenths, placeholder: "Вес")
                        .textFieldStyle(.roundedBorder)
                    Menu {
                        ForEach(WeightUnit.allCases) { unit in
                            Button(unit.rawValue) { changeUnit(to: unit) }
                        }
                    } label: {
                        Text(set.unit.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(width: 38)
                }
                OptionalRepsField(reps: $set.actualReps, placeholder: "Повт.")
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
            }
        }
        .padding(.vertical, 3)
    }

    private func changeUnit(to unit: WeightUnit) {
        guard unit != set.unit else { return }
        if let load = set.plannedLoadTenths {
            set.plannedLoadTenths = set.unit.converted(loadTenths: load, to: unit)
        }
        if let load = set.actualLoadTenths {
            set.actualLoadTenths = set.unit.converted(loadTenths: load, to: unit)
        }
        set.unit = unit
    }
}

private struct WeightManagerRequest: Identifiable {
    let id = UUID()
}

private struct WeightMeasurementDraft: Identifiable {
    let id = UUID()
}

private struct BodyWeightManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyWeightEntry.day, order: .reverse) private var weights: [BodyWeightEntry]
    @State private var newMeasurement: WeightMeasurementDraft?

    var body: some View {
        NavigationStack {
            List {
                if weights.isEmpty {
                    ContentUnavailableView(
                        "Нет замеров",
                        systemImage: "scalemass",
                        description: Text("Добавьте вес тела, чтобы увидеть динамику на графике.")
                    )
                } else {
                    ForEach(weights) { entry in
                        LabeledContent(entry.day.formatted(date: .long, time: .omitted)) {
                            Text("\(Double(entry.weightTenthsKg) / 10, format: .number.precision(.fractionLength(1))) кг")
                                .fontWeight(.medium)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Замеры веса")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Добавить", systemImage: "plus") {
                        newMeasurement = WeightMeasurementDraft()
                    }
                    .accessibilityIdentifier("progress.addWeight")
                }
            }
        }
        .sheet(item: $newMeasurement) { _ in
            BodyWeightEditorView()
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(weights[index]) }
        try? modelContext.save()
    }
}

private struct BodyWeightEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var day = Date()
    @State private var weight = ""

    private var weightTenths: Int? {
        let normalized = weight.replacingOccurrences(of: ",", with: ".")
        return Double(normalized).map { Int(($0 * 10).rounded()) }
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Дата", selection: $day, displayedComponents: .date)
                TextField("Вес, кг", text: $weight)
                    .keyboardType(.decimalPad)
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Новый замер")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(weightTenths == nil)
                }
            }
        }
    }

    private func save() {
        guard let weightTenths else { return }
        let normalizedDay = Calendar.current.startOfDay(for: day)
        let descriptor = FetchDescriptor<BodyWeightEntry>(predicate: #Predicate { $0.day == normalizedDay })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.weightTenthsKg = weightTenths
        } else {
            modelContext.insert(BodyWeightEntry(day: normalizedDay, weightTenthsKg: weightTenths))
        }
        try? modelContext.save()
        dismiss()
    }
}
