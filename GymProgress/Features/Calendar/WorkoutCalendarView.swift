import SwiftData
import SwiftUI

struct WorkoutCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduledWorkout.scheduledAt) private var schedules: [ScheduledWorkout]
    @Query(sort: \WorkoutTemplate.order) private var templates: [WorkoutTemplate]
    @Query(
        filter: #Predicate<WorkoutSession> { $0.statusRaw == "completed" },
        sort: \WorkoutSession.startedAt
    ) private var completedSessions: [WorkoutSession]
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]

    @State private var selectedDate = Date()
    @State private var showNewWorkout = false
    @State private var editingWorkout: ScheduledWorkout?

    private var selectedSchedules: [ScheduledWorkout] {
        schedules.filter { workout in
            guard Calendar.current.isDate(workout.scheduledAt, inSameDayAs: selectedDate) else { return false }
            guard workout.status == .completed, let sessionID = workout.sessionID else { return true }
            return sessions.contains(where: { $0.id == sessionID })
        }
    }

    private var completedWorkoutDays: Set<Date> {
        Set(completedSessions.map {
            Calendar.current.startOfDay(for: $0.endedAt ?? $0.startedAt)
        })
    }

    private var plannedWorkoutDays: Set<Date> {
        Set(schedules.filter { $0.status == .planned }.map {
            Calendar.current.startOfDay(for: $0.scheduledAt)
        })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WorkoutMonthCalendar(
                        selectedDate: $selectedDate,
                        completedDays: completedWorkoutDays,
                        plannedDays: plannedWorkoutDays
                    )
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
                                ScheduleRow(
                                    workout: workout,
                                    templateName: templates.first(where: { $0.id == workout.templateID })?.name ?? workout.templateName
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(workout.status == .completed || workout.status == .inProgress)
                            .swipeActions(edge: .trailing) {
                                if workout.status != .inProgress {
                                    Button("Удалить", role: .destructive) { delete(workout) }
                                }
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
        .onAppear(perform: removeOrphanedCompletedSchedules)
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

    private func removeOrphanedCompletedSchedules() {
        let sessionIDs = Set(sessions.map(\.id))
        for workout in schedules where workout.status == .completed
            && workout.sessionID != nil
            && !sessionIDs.contains(workout.sessionID!) {
            NotificationService.cancel(workoutID: workout.id)
            modelContext.delete(workout)
        }
        try? modelContext.save()
    }
}

private struct WorkoutMonthCalendar: View {
    @Binding var selectedDate: Date
    let completedDays: Set<Date>
    let plannedDays: Set<Date>
    @State private var displayedMonth: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    init(selectedDate: Binding<Date>, completedDays: Set<Date>, plannedDays: Set<Date>) {
        _selectedDate = selectedDate
        self.completedDays = completedDays
        self.plannedDays = plannedDays
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate.wrappedValue)
        _displayedMonth = State(initialValue: Calendar.current.date(from: components) ?? selectedDate.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button("Предыдущий месяц", systemImage: "chevron.left") { changeMonth(by: -1) }
                    .labelStyle(.iconOnly)
                Spacer()
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                Spacer()
                Button("Следующий месяц", systemImage: "chevron.right") { changeMonth(by: 1) }
                    .labelStyle(.iconOnly)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                ForEach(Array(monthGrid.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var monthGrid: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let weekday = calendar.component(.weekday, from: displayedMonth)
        let leadingEmptyDays = (weekday + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        days += dayRange.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: displayedMonth) }
        let trailingEmptyDays = (7 - days.count % 7) % 7
        days += Array(repeating: nil, count: trailingEmptyDays)
        return days
    }

    private func dayButton(_ day: Date) -> some View {
        let normalizedDay = calendar.startOfDay(for: day)
        let hasCompletedWorkout = completedDays.contains(normalizedDay)
        let hasPlannedWorkout = plannedDays.contains(normalizedDay)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.day()))
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .frame(width: 32, height: 32)
                    .background(dayColor(completed: hasCompletedWorkout, planned: hasPlannedWorkout).opacity(0.18))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(isSelected ? AppTheme.accent : .clear, lineWidth: 2)
                    }
                HStack(spacing: 3) {
                    if hasCompletedWorkout { statusDot(color: AppTheme.success) }
                    if hasPlannedWorkout { statusDot(color: AppTheme.accent) }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day, completed: hasCompletedWorkout, planned: hasPlannedWorkout))
    }

    private func dayColor(completed: Bool, planned: Bool) -> Color {
        completed ? AppTheme.success : (planned ? AppTheme.accent : .clear)
    }

    private func statusDot(color: Color) -> some View {
        Circle().fill(color).frame(width: 4, height: 4)
    }

    private func accessibilityLabel(for day: Date, completed: Bool, planned: Bool) -> String {
        var label = day.formatted(date: .long, time: .omitted)
        if completed { label += ", тренировка выполнена" }
        if planned { label += ", тренировка запланирована" }
        return label
    }

    private func changeMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = month
    }
}

private struct ScheduleRow: View {
    let workout: ScheduledWorkout
    let templateName: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(templateName)
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
        case .inProgress: "Идёт"
        case .completed: "Выполнена"
        case .skipped: "Пропущена"
        }
    }

    private var statusColor: Color {
        switch workout.status {
        case .planned: AppTheme.accent
        case .inProgress: .orange
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
                        Stepper(reminderText, value: $reminderMinutes, in: 5...1_440, step: 5)
                        Text("Выберите, за сколько до начала тренировки придёт локальное уведомление.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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

    private var reminderText: String {
        if reminderMinutes < 60 { return "За \(reminderMinutes) мин." }
        if reminderMinutes.isMultiple(of: 60) {
            let hours = reminderMinutes / 60
            return hours == 1 ? "За 1 час" : "За \(hours) ч."
        }
        return "За \(reminderMinutes / 60) ч. \(reminderMinutes % 60) мин."
    }
}
