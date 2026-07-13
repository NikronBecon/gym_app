import SwiftData
import SwiftUI

struct TodayView: View {
    @Query(sort: \WorkoutTemplate.order) private var templates: [WorkoutTemplate]
    @Query private var schedules: [ScheduledWorkout]
    @Query private var sessions: [WorkoutSession]

    @State private var templateToStart: WorkoutTemplate?
    @State private var scheduledIDToStart: UUID?
    @State private var shownSession: WorkoutSession?

    private var activeSession: WorkoutSession? {
        sessions.first { $0.status == .active }
    }

    private var nextSchedule: ScheduledWorkout? {
        schedules
            .filter { $0.status == .planned }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let activeSession {
                        activeCard(activeSession)
                    }
                    if let nextSchedule {
                        scheduleCard(nextSchedule)
                    } else {
                        emptyScheduleCard
                    }
                    templatesSection
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Сегодня")
            .toolbar {
                NavigationLink {
                    TemplateListView()
                } label: {
                    Label("Шаблоны", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(item: $templateToStart) { template in
            StartWorkoutSheet(
                template: template,
                scheduledWorkoutID: scheduledIDToStart
            ) { session in
                shownSession = session
                templateToStart = nil
                scheduledIDToStart = nil
            }
        }
        .fullScreenCover(item: $shownSession) { session in
            WorkoutView(session: session) {
                shownSession = nil
            }
        }
    }

    private func activeCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Тренировка идёт", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
            Text(session.name)
                .font(.title2.bold())
            Text("Начата \(session.startedAt.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(AppTheme.secondaryText)
            Button("Продолжить") { shownSession = session }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("today.resumeWorkout")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func scheduleCard(_ schedule: ScheduledWorkout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ближайшая тренировка")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Text(schedule.templateName)
                .font(.title2.bold())
            Label(
                schedule.scheduledAt.formatted(date: .abbreviated, time: .shortened),
                systemImage: "calendar"
            )
            Button("Начать тренировку") {
                guard activeSession == nil,
                      let template = templates.first(where: { $0.id == schedule.templateID }) else { return }
                scheduledIDToStart = schedule.id
                templateToStart = template
            }
            .buttonStyle(.borderedProminent)
            .disabled(activeSession != nil)
            .accessibilityIdentifier("today.startScheduled")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var emptyScheduleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Нет запланированной тренировки")
                .font(.headline)
            Text("Выберите шаблон ниже или назначьте дату в календаре.")
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Начать из шаблона")
                .font(.title3.bold())
            ForEach(templates) { template in
                Button {
                    guard activeSession == nil else { return }
                    scheduledIDToStart = nil
                    templateToStart = template
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Text("\(template.slots.count) упражнений")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                    .appCard()
                }
                .buttonStyle(.plain)
                .disabled(activeSession != nil)
            }
        }
    }
}

private struct StartWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let template: WorkoutTemplate
    let scheduledWorkoutID: UUID?
    let onStarted: (WorkoutSession) -> Void

    @State private var choices: [UUID: UUID] = [:]
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Упражнения") {
                    ForEach(template.sortedSlots) { slot in
                        if slot.variants.count == 1, let variant = slot.variants.first {
                            Text(ExerciseCatalog.shared.item(id: variant.catalogID)?.name ?? variant.catalogID)
                        } else {
                            Picker("Выберите вариант", selection: choiceBinding(for: slot)) {
                                ForEach(slot.variants) { variant in
                                    Text(ExerciseCatalog.shared.item(id: variant.catalogID)?.name ?? variant.catalogID)
                                        .tag(variant.id)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(template.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Начать") { start() }
                        .accessibilityIdentifier("startWorkout.confirm")
                }
            }
            .alert("Не удалось начать", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("Закрыть", role: .cancel) {}
            } message: {
                Text(errorText ?? "Неизвестная ошибка")
            }
        }
        .onAppear {
            for slot in template.slots where choices[slot.id] == nil {
                choices[slot.id] = slot.variants.first?.id
            }
        }
    }

    private func choiceBinding(for slot: TemplateSlot) -> Binding<UUID> {
        Binding(
            get: { choices[slot.id] ?? slot.variants.first?.id ?? UUID() },
            set: { choices[slot.id] = $0 }
        )
    }

    private func start() {
        do {
            let session = try WorkoutBuilder.start(
                template: template,
                choices: choices,
                scheduledWorkoutID: scheduledWorkoutID,
                context: modelContext
            )
            dismiss()
            onStarted(session)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
