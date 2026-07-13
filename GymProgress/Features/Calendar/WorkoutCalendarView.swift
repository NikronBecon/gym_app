import SwiftData
import SwiftUI

struct WorkoutCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduledWorkout.scheduledAt) private var schedules: [ScheduledWorkout]
    @Query(sort: \WorkoutTemplate.order) private var templates: [WorkoutTemplate]

    @State private var selectedDate = Date()
    @State private var showNewWorkout = false
    @State private var editingWorkout: ScheduledWorkout?

    private var selectedSchedules: [ScheduledWorkout] {
        schedules.filter { Calendar.current.isDate($0.scheduledAt, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker(
                        "Дата",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .accessibilityIdentifier("calendar.datePicker")
                }

                Section(selectedDate.formatted(date: .long, time: .omitted)) {
                    if selectedSchedules.isEmpty {
                        ContentUnavailableView(
                            "Нет тренировок",
                            systemImage: "calendar.badge.plus",
                            description: Text("Назначьте один из шаблонов на этот день.")
                        )
                    } else {
                        ForEach(selectedSchedules) { workout in
                            Button { editingWorkout = workout } label: {
                                ScheduleRow(workout: workout)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("Удалить", role: .destructive) { delete(workout) }
                                if workout.status == .planned {
                                    Button("Пропустить") { skip(workout) }
                                        .tint(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Календарь")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewWorkout = true
                    } label: {
                        Label("Назначить", systemImage: "plus")
                    }
                    .disabled(templates.isEmpty)
                    .accessibilityIdentifier("calendar.addWorkout")
                }
            }
        }
        .sheet(isPresented: $showNewWorkout) {
            ScheduleEditorView(
                workout: nil,
                templates: templates,
                selectedDate: selectedDate
            )
        }
        .sheet(item: $editingWorkout) { workout in
            ScheduleEditorView(
                workout: workout,
                templates: templates,
                selectedDate: workout.scheduledAt
            )
        }
    }

    private func skip(_ workout: ScheduledWorkout) {
        workout.status = .skipped
        NotificationService.cancel(workoutID: workout.id)
        try? modelContext.save()
    }

    private func delete(_ workout: ScheduledWorkout) {
        NotificationService.cancel(workoutID: workout.id)
        modelContext.delete(workout)
        try? modelContext.save()
    }
}

private struct ScheduleRow: View {
    let workout: ScheduledWorkout

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.templateName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(workout.scheduledAt.formatted(date: .omitted, time: .shortened))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text(statusText)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.13))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch workout.status {
        case .planned: "Запланирована"
        case .completed: "Выполнена"
        case .skipped: "Пропущена"
        }
    }

    private var statusColor: Color {
        switch workout.status {
        case .planned: AppTheme.accent
        case .completed: AppTheme.success
        case .skipped: .gray
        }
    }
}

private struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workout: ScheduledWorkout?
    let templates: [WorkoutTemplate]

    @State private var templateID: UUID
    @State private var date: Date
    @State private var reminderEnabled: Bool
    @State private var reminderMinutes: Int

    init(
        workout: ScheduledWorkout?,
        templates: [WorkoutTemplate],
        selectedDate: Date
    ) {
        self.workout = workout
        self.templates = templates
        let defaultTemplateID = workout?.templateID ?? templates.first?.id ?? UUID()
        let defaultDate = workout?.scheduledAt
            ?? Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: selectedDate)
            ?? selectedDate
        _templateID = State(initialValue: defaultTemplateID)
        _date = State(initialValue: defaultDate)
        _reminderEnabled = State(initialValue: workout?.reminderMinutes != nil)
        _reminderMinutes = State(initialValue: workout?.reminderMinutes ?? 120)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Тренировка") {
                    Picker("Шаблон", selection: $templateID) {
                        ForEach(templates) { Text($0.name).tag($0.id) }
                    }
                    DatePicker("Дата и время", selection: $date)
                }
                Section("Напоминание") {
                    Toggle("Напомнить", isOn: $reminderEnabled)
                    if reminderEnabled {
                        Picker("Когда", selection: $reminderMinutes) {
                            Text("За 30 минут").tag(30)
                            Text("За 1 час").tag(60)
                            Text("За 2 часа").tag(120)
                            Text("За день").tag(1_440)
                        }
                    }
                }
            }
            .navigationTitle(workout == nil ? "Новая тренировка" : "Редактирование")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(templates.first(where: { $0.id == templateID }) == nil)
                        .accessibilityIdentifier("schedule.save")
                }
            }
        }
    }

    private func save() {
        guard let template = templates.first(where: { $0.id == templateID }) else { return }
        let item: ScheduledWorkout
        if let workout {
            NotificationService.cancel(workoutID: workout.id)
            workout.templateID = template.id
            workout.templateName = template.name
            workout.scheduledAt = date
            workout.reminderMinutes = reminderEnabled ? reminderMinutes : nil
            workout.status = .planned
            item = workout
        } else {
            item = ScheduledWorkout(
                templateID: template.id,
                templateName: template.name,
                scheduledAt: date,
                reminderMinutes: reminderEnabled ? reminderMinutes : nil
            )
            modelContext.insert(item)
        }
        try? modelContext.save()
        Task { await NotificationService.schedule(for: item) }
        dismiss()
    }
}
