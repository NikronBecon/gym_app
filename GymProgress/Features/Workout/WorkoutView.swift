import SwiftData
import SwiftUI
import UIKit

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    let onFinished: () -> Void

    @State private var showFinish = false

    private var incompleteCount: Int {
        session.exercises.flatMap(\.sets).filter { !$0.isCompleted }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    timerCard
                    ForEach(session.sortedExercises) { exercise in
                        SessionExerciseCard(
                            exercise: exercise,
                            onSetCompleted: { startRest(seconds: exercise.restSeconds) }
                        )
                    }
                    Button("Завершить тренировку") { showFinish = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("workout.finish")
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(session.startedAt, style: .timer)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .accessibilityLabel("Длительность тренировки")
                    }
                }
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

    @ViewBuilder
    private var timerCard: some View {
        if let end = session.restEndDate, end > .now {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(end.timeIntervalSince(context.date).rounded(.up)))
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading) {
                        Text("Отдых")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text(durationText(remaining))
                            .font(.title2.monospacedDigit().bold())
                    }
                    Spacer()
                    Button("Пропустить") { session.restEndDate = nil }
                }
                .frame(maxWidth: .infinity)
                .appCard()
                .onChange(of: remaining) { oldValue, newValue in
                    if oldValue > 0, newValue == 0 {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        session.restEndDate = nil
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    private func startRest(seconds: Int) {
        session.restEndDate = .now.addingTimeInterval(TimeInterval(seconds))
        try? modelContext.save()
    }

    private func durationText(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct SessionExerciseCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: SessionExercise
    let onSetCompleted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.nameSnapshot)
                        .font(.headline)
                    Text("Отдых \(exercise.restSeconds) сек.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
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
                Text("Ориентир").frame(maxWidth: .infinity)
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
                    onCompleted: onSetCompleted
                )
                .contextMenu {
                    Button("Удалить подход", role: .destructive) { delete(set) }
                }
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
    let onCompleted: () -> Void

    var body: some View {
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
                VStack(spacing: 0) {
                    OptionalLoadField(loadTenths: $set.actualLoadTenths)
                    Text(set.unit.rawValue)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(width: 62)
                .onTapGesture {
                    set.unit = set.unit == .kg ? .lb : .kg
                }
            }
            OptionalRepsField(reps: $set.actualReps)
                .frame(width: 52)
            Button {
                set.isCompleted.toggle()
                set.completedAt = set.isCompleted ? .now : nil
                try? modelContext.save()
                if set.isCompleted { onCompleted() }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.isCompleted ? AppTheme.success : AppTheme.secondaryText)
            }
            .frame(width: 34)
            .disabled(set.actualReps == nil)
            .accessibilityLabel(set.isCompleted ? "Подход выполнен" : "Отметить подход")
        }
        .padding(.vertical, 4)
        .opacity(set.isCompleted ? 0.72 : 1)
    }

    private var referenceText: String {
        let load = set.plannedLoadTenths.map { "\($0.loadText) \(set.unit.rawValue)" } ?? "—"
        let reps = set.plannedReps.map(String.init) ?? "—"
        return "\(load) × \(reps)"
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
                        Label("Не заполнено: \(incompleteCount)", systemImage: "exclamationmark.triangle.fill")
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
            let entries = (try? modelContext.fetch(FetchDescriptor<BodyWeightEntry>())) ?? []
            if let existing = entries.first(where: { Calendar.current.isDate($0.day, inSameDayAs: day) }) {
                existing.weightTenthsKg = Int((value * 10).rounded())
            } else {
                modelContext.insert(BodyWeightEntry(day: day, weightTenthsKg: Int((value * 10).rounded())))
            }
        }

        if let scheduledID = session.scheduledWorkoutID {
            let schedules = (try? modelContext.fetch(FetchDescriptor<ScheduledWorkout>())) ?? []
            if let schedule = schedules.first(where: { $0.id == scheduledID }) {
                schedule.status = .completed
                schedule.sessionID = session.id
                NotificationService.cancel(workoutID: schedule.id)
            }
        }

        try? modelContext.save()
        onFinished()
    }
}
