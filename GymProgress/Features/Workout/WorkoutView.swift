import SwiftData
import SwiftUI
import UIKit

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    let onFinished: () -> Void

    @State private var showFinish = false
    @State private var showCatalog = false

    private var incompleteCount: Int {
        session.exercises.flatMap { exercise in
            exercise.sets.filter { set in
                set.actualReps == nil || (exercise.loadMode != .bodyweight && set.actualLoadTenths == nil)
            }
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(session.sortedExercises) { exercise in
                        SessionExerciseCard(exercise: exercise)
                    }
                    Button("Добавить упражнение", systemImage: "plus") { showCatalog = true }
                        .buttonStyle(.bordered)
                    Text("Добавленное упражнение появится только в этой тренировке и не изменит шаблон.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Завершить тренировку") { showFinish = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("workout.finish")
                }
                .padding()
            }
            .background(AppTheme.background)
            .dismissKeyboardOnTap()
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Выйти", systemImage: "chevron.backward") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(session.startedAt, style: .timer)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .accessibilityLabel("Длительность тренировки")
                    }
                }
            }
        }
        .sheet(isPresented: $showCatalog) {
            CatalogPickerView { item in
                addExercise(item)
            }
        }
        .sheet(isPresented: $showFinish) {
            FinishWorkoutView(session: session, incompleteCount: incompleteCount) {
                showFinish = false
                onFinished()
                dismiss()
            }
        }
    }

    private func addExercise(_ item: ExerciseCatalogItem) {
        let sets = (0..<3).map { index in
            SetRecord(
                order: index,
                plannedLoadTenths: nil,
                plannedReps: nil,
                actualLoadTenths: nil,
                actualReps: nil,
                unit: item.defaultUnit
            )
        }
        session.exercises.append(SessionExercise(
            catalogID: item.id,
            nameSnapshot: item.name,
            order: session.exercises.count,
            restSeconds: 90,
            loadMode: item.loadMode,
            sets: sets
        ))
        try? modelContext.save()
    }

    private func durationText(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct SessionExerciseCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: SessionExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.nameSnapshot)
                        .font(.headline)
                }
                Spacer()
                NavigationLink {
                    if let item = ExerciseCatalog.shared.item(id: exercise.catalogID) {
                        ExerciseDetailView(item: item)
                    }
                } label: {
                    Image(systemName: "info.circle")
                }
            }

            HStack {
                Text("№").frame(width: 24)
                Text("Прошлый раз").frame(maxWidth: .infinity)
                Text("Вес").frame(width: 62)
                Text("Повт.").frame(width: 52)
                Color.clear.frame(width: 34)
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)

            ForEach(exercise.sortedSets) { set in
                SessionSetRow(
                    set: set,
                    loadMode: exercise.loadMode,
                    onDelete: { delete(set) },
                    canDelete: exercise.sets.count > 1
                )
            }

            Button("Добавить подход", systemImage: "plus") { addSet() }
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func addSet() {
        let last = exercise.sortedSets.last
        exercise.sets.append(SetRecord(
            order: exercise.sets.count,
            plannedLoadTenths: last?.actualLoadTenths,
            plannedReps: last?.actualReps,
            actualLoadTenths: last?.actualLoadTenths,
            actualReps: last?.actualReps,
            unit: last?.unit ?? .kg
        ))
        try? modelContext.save()
    }

    private func delete(_ set: SetRecord) {
        exercise.sets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        for (index, set) in exercise.sortedSets.enumerated() { set.order = index }
        try? modelContext.save()
    }
}

private struct SessionSetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var set: SetRecord
    let loadMode: LoadMode
    let onDelete: () -> Void
    let canDelete: Bool
    @State private var swipeOffset: CGFloat = 0
    @State private var completionPulse = false

    var body: some View {
        rowContent
            .offset(x: swipeOffset)
            .gesture(deleteGesture)
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Text("\(set.order + 1)")
                .font(.subheadline.monospacedDigit())
                .frame(width: 24)
            Text(referenceText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity)
            if loadMode == .bodyweight {
                Text("—").frame(width: 62)
            } else {
                HStack(spacing: 2) {
                    OptionalLoadField(loadTenths: $set.actualLoadTenths)
                    Menu {
                        ForEach(WeightUnit.allCases) { unit in
                            Button(unit.rawValue) { changeUnit(to: unit) }
                        }
                    } label: {
                        Text(set.unit.rawValue)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .frame(width: 62)
            }
            OptionalRepsField(reps: $set.actualReps)
                .frame(width: 52)
            Button {
                toggleCompletion()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.isCompleted ? AppTheme.success : AppTheme.secondaryText)
            }
            .frame(width: 34)
            .disabled(!canComplete)
            .accessibilityLabel(set.isCompleted ? "Подход выполнен" : "Отметить подход")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(set.isCompleted ? AppTheme.success.opacity(0.14) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .scaleEffect(completionPulse ? 1.015 : 1)
        .animation(.spring(response: 0.26, dampingFraction: 0.68), value: completionPulse)
    }

    private var referenceText: String {
        let load = set.plannedLoadTenths.map { "\($0.loadText) \(set.unit.rawValue)" } ?? "—"
        let reps = set.plannedReps.map(String.init) ?? "—"
        return "\(load) × \(reps)"
    }

    private var canComplete: Bool {
        return set.actualReps != nil && (loadMode == .bodyweight || set.actualLoadTenths != nil)
    }

    private var deleteGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard canDelete else { return }
                swipeOffset = min(0, max(-72, value.translation.width))
            }
            .onEnded { value in
                guard canDelete else { return }
                if value.translation.width < -52 {
                    onDelete()
                } else {
                    withAnimation(.snappy) {
                        swipeOffset = 0
                    }
                }
            }
    }

    private func toggleCompletion() {
        let willComplete = !set.isCompleted
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            set.isCompleted = willComplete
            set.completedAt = willComplete ? .now : nil
            completionPulse = willComplete
        }
        try? modelContext.save()

        guard willComplete else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            completionPulse = false
        }
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
        try? modelContext.save()
    }
}

private struct FinishWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    let incompleteCount: Int
    let onFinished: () -> Void

    @State private var bodyWeight = ""
    @State private var calories = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Итог") {
                    LabeledContent("Длительность", value: durationText)
                    LabeledContent("Выполнено подходов", value: "\(completedCount)")
                    if incompleteCount > 0 {
                        Label("Без веса или повторов: \(incompleteCount)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Section("Необязательно") {
                    TextField("Вес тела, кг", text: $bodyWeight)
                        .keyboardType(.decimalPad)
                    TextField("Калории", text: $calories)
                        .keyboardType(.numberPad)
                    TextField("Заметка", text: $session.note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Завершение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Назад") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { complete() }
                        .accessibilityIdentifier("finishWorkout.save")
                }
            }
        }
    }

    private var completedCount: Int {
        session.exercises.flatMap(\.sets).filter(\.isCompleted).count
    }

    private var durationText: String {
        let seconds = max(0, Int(session.duration))
        return String(format: "%d:%02d:%02d", seconds / 3_600, (seconds % 3_600) / 60, seconds % 60)
    }

    private func complete() {
        session.endedAt = .now
        session.status = .completed
        session.restEndDate = nil
        session.calories = Int(calories)

        let normalizedWeight = bodyWeight.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalizedWeight) {
            let day = Calendar.current.startOfDay(for: .now)
            let descriptor = FetchDescriptor<BodyWeightEntry>(predicate: #Predicate { $0.day == day })
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.weightTenthsKg = Int((value * 10).rounded())
            } else {
                modelContext.insert(BodyWeightEntry(day: day, weightTenthsKg: Int((value * 10).rounded())))
            }
        }

        if let scheduledID = session.scheduledWorkoutID {
            let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: #Predicate { $0.id == scheduledID })
            if let schedule = try? modelContext.fetch(descriptor).first {
                schedule.status = .completed
                schedule.sessionID = session.id
                NotificationService.cancel(workoutID: schedule.id)
            }
        }

        try? modelContext.save()
        onFinished()
    }
}
