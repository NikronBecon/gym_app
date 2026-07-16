import SwiftData
import SwiftUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.order) private var templates: [WorkoutTemplate]
    @State private var templatesPendingDeletion: [WorkoutTemplate] = []

    var body: some View {
        List {
            ForEach(templates) { template in
                NavigationLink(template.name) {
                    TemplateEditorView(template: template)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Шаблоны")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addTemplate) {
                    Label("Новый шаблон", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .alert(
            "Удалить шаблон?",
            isPresented: Binding(
                get: { !templatesPendingDeletion.isEmpty },
                set: { if !$0 { templatesPendingDeletion = [] } }
            )
        ) {
            Button("Удалить", role: .destructive, action: confirmDelete)
            Button("Отмена", role: .cancel) { templatesPendingDeletion = [] }
        } message: {
            Text("Шаблон и запланированные по нему тренировки будут удалены. История уже выполненных тренировок сохранится.")
        }
    }

    private func addTemplate() {
        modelContext.insert(WorkoutTemplate(name: "Новая тренировка", order: templates.count))
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet) {
        templatesPendingDeletion = offsets.map { templates[$0] }
    }

    private func confirmDelete() {
        try? TemplateService.delete(templatesPendingDeletion, context: modelContext)
        templatesPendingDeletion = []
    }
}

@MainActor
enum TemplateService {
    static func delete(_ templates: [WorkoutTemplate], context: ModelContext) throws {
        let templateIDs = Set(templates.map(\.id))
        let schedules = try context.fetch(FetchDescriptor<ScheduledWorkout>())
        for schedule in schedules where schedule.status == .planned && templateIDs.contains(schedule.templateID) {
            NotificationService.cancel(workoutID: schedule.id)
            context.delete(schedule)
        }
        for template in templates { context.delete(template) }
        try context.save()
    }

    static func syncPlannedSchedules(for template: WorkoutTemplate, context: ModelContext) {
        guard let schedules = try? context.fetch(FetchDescriptor<ScheduledWorkout>()) else { return }
        for schedule in schedules where schedule.status == .planned && schedule.templateID == template.id {
            schedule.templateName = template.name
            Task { await NotificationService.schedule(for: schedule) }
        }
        try? context.save()
    }

    static func sync(for template: WorkoutTemplate, context: ModelContext) {
        syncPlannedSchedules(for: template, context: context)
        syncActiveSessions(for: template, context: context)
    }

    static func syncActiveSessions(for template: WorkoutTemplate, context: ModelContext) {
        guard let sessions = try? context.fetch(FetchDescriptor<WorkoutSession>()) else { return }

        for session in sessions where session.status == .active && session.templateID == template.id {
            sync(session: session, with: template)
        }
        try? context.save()
    }

    static func syncAllActiveSessions(context: ModelContext) {
        guard let templates = try? context.fetch(FetchDescriptor<WorkoutTemplate>()) else { return }
        for template in templates {
            syncActiveSessions(for: template, context: context)
        }
    }

    private static func sync(session: WorkoutSession, with template: WorkoutTemplate) {
        session.name = template.name
        var matchedExerciseIDs = Set<UUID>()

        for (slotIndex, slot) in template.sortedSlots.enumerated() {
            guard let selected = selectedVariant(for: slot, in: session) else { continue }
            let item = ExerciseCatalog.shared.item(id: selected.catalogID)
            let existing = session.exercises.first {
                !matchedExerciseIDs.contains($0.id)
                    && $0.catalogID == selected.catalogID
            }

            let exercise: SessionExercise
            if let existing {
                exercise = existing
            } else {
                exercise = SessionExercise(
                    catalogID: selected.catalogID,
                    nameSnapshot: item?.name ?? selected.catalogID,
                    order: slotIndex,
                    restSeconds: selected.restSeconds,
                    loadMode: item?.loadMode ?? .total
                )
                session.exercises.append(exercise)
            }

            matchedExerciseIDs.insert(exercise.id)
            exercise.catalogID = selected.catalogID
            exercise.nameSnapshot = item?.name ?? selected.catalogID
            exercise.order = slotIndex
            exercise.restSeconds = selected.restSeconds
            exercise.loadModeRaw = (item?.loadMode ?? .total).rawValue
            syncPendingSets(in: exercise, from: selected)
        }

        let templateExerciseCount = template.sortedSlots.count
        for (offset, exercise) in session.sortedExercises.enumerated() where !matchedExerciseIDs.contains(exercise.id) {
            exercise.order = templateExerciseCount + offset
        }
    }

    private static func selectedVariant(for slot: TemplateSlot, in session: WorkoutSession) -> TemplateVariant? {
        slot.variants.first { variant in
            session.exercises.contains(where: { $0.catalogID == variant.catalogID })
        } ?? slot.variants.first
    }

    private static func syncPendingSets(in exercise: SessionExercise, from variant: TemplateVariant) {
        for (index, planned) in variant.sortedSets.enumerated() {
            if let set = exercise.sortedSets[safe: index] {
                guard !set.isCompleted else { continue }
                let wasAutofilled = set.actualLoadTenths == set.plannedLoadTenths
                    && set.actualReps == set.plannedReps
                set.plannedLoadTenths = planned.loadTenths
                set.plannedReps = planned.reps
                set.unit = planned.unit
                if wasAutofilled {
                    set.actualLoadTenths = planned.loadTenths
                    set.actualReps = planned.reps
                }
            } else {
                exercise.sets.append(SetRecord(
                    order: index,
                    plannedLoadTenths: planned.loadTenths,
                    plannedReps: planned.reps,
                    actualLoadTenths: planned.loadTenths,
                    actualReps: planned.reps,
                    unit: planned.unit
                ))
            }
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: WorkoutTemplate
    @State private var showCatalog = false

    var body: some View {
        List {
            Section("Название") {
                TextField("Название", text: $template.name)
            }
            Section("Упражнения") {
                ForEach(template.sortedSlots) { slot in
                    NavigationLink {
                        SlotEditorView(slot: slot)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(slot.variants.first.flatMap {
                                ExerciseCatalog.shared.item(id: $0.catalogID)?.name
                            } ?? "Упражнение")
                            if slot.variants.count > 1 {
                                Text("\(slot.variants.count) варианта")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                Button("Добавить упражнение", systemImage: "plus") { showCatalog = true }
            }
        }
        .dismissKeyboardOnTap()
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            TemplateService.sync(for: template, context: modelContext)
        }
        .onChange(of: template.name) { _, _ in
            TemplateService.sync(for: template, context: modelContext)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .sheet(isPresented: $showCatalog) {
            CatalogPickerView { item in
                let sets = (0..<3).map {
                    PlannedSet(order: $0, loadTenths: nil, reps: nil, unit: item.defaultUnit)
                }
                let variant = TemplateVariant(catalogID: item.id, plannedSets: sets)
                template.slots.append(TemplateSlot(order: template.slots.count, variants: [variant]))
                try? modelContext.save()
                TemplateService.sync(for: template, context: modelContext)
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = template.sortedSlots
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, slot) in ordered.enumerated() { slot.order = index }
        try? modelContext.save()
        TemplateService.sync(for: template, context: modelContext)
    }

    private func delete(at offsets: IndexSet) {
        let ordered = template.sortedSlots
        for index in offsets {
            let slot = ordered[index]
            template.slots.removeAll { $0.id == slot.id }
            modelContext.delete(slot)
        }
        try? modelContext.save()
        TemplateService.sync(for: template, context: modelContext)
    }
}

private struct SlotEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var slot: TemplateSlot
    @State private var showCatalog = false

    var body: some View {
        List {
            Section("Варианты") {
                ForEach(slot.variants) { variant in
                    NavigationLink {
                        VariantEditorView(variant: variant)
                    } label: {
                        Text(ExerciseCatalog.shared.item(id: variant.catalogID)?.name ?? variant.catalogID)
                    }
                }
                .onDelete(perform: delete)
                Button("Добавить вариант", systemImage: "plus") { showCatalog = true }
            }
            Section {
                Text("Во время запуска тренировки приложение попросит выбрать один вариант.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Варианты")
        .onDisappear {
            TemplateService.syncAllActiveSessions(context: modelContext)
        }
        .sheet(isPresented: $showCatalog) {
            CatalogPickerView { item in
                let sets = (0..<3).map {
                    PlannedSet(order: $0, loadTenths: nil, reps: nil, unit: item.defaultUnit)
                }
                slot.variants.append(TemplateVariant(catalogID: item.id, plannedSets: sets))
                try? modelContext.save()
                TemplateService.syncAllActiveSessions(context: modelContext)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        guard slot.variants.count > offsets.count else { return }
        for index in offsets.sorted(by: >) {
            let variant = slot.variants.remove(at: index)
            modelContext.delete(variant)
        }
        try? modelContext.save()
        TemplateService.syncAllActiveSessions(context: modelContext)
    }
}

private struct VariantEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var variant: TemplateVariant

    var body: some View {
        Form {
            Section("Подходы") {
                Text("План для первой тренировки: укажите вес и повторы. Можно оставить поля пустыми. Затем ориентир будет подставляться из последних выполненных подходов.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("№").frame(width: 24)
                    Text("Вес").frame(maxWidth: .infinity)
                    Text("Ед.").frame(width: 52)
                    Text("Повт.").frame(width: 58)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(variant.sortedSets) { set in
                    PlannedSetEditorRow(
                        set: set,
                        canDelete: variant.plannedSets.count > 1,
                        onDelete: { delete(set) }
                    )
                }

                Button("Добавить подход", systemImage: "plus") {
                    let unit = variant.plannedSets.last?.unit
                        ?? ExerciseCatalog.shared.item(id: variant.catalogID)?.defaultUnit
                        ?? .kg
                    variant.plannedSets.append(PlannedSet(
                        order: variant.plannedSets.count,
                        loadTenths: variant.plannedSets.last?.loadTenths,
                        reps: variant.plannedSets.last?.reps,
                        unit: unit
                    ))
                    try? modelContext.save()
                }
            }
        }
        .dismissKeyboardOnTap()
        .navigationTitle(ExerciseCatalog.shared.item(id: variant.catalogID)?.name ?? "Упражнение")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            TemplateService.syncAllActiveSessions(context: modelContext)
        }
    }

    private func delete(_ set: PlannedSet) {
        variant.plannedSets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        for (index, set) in variant.sortedSets.enumerated() { set.order = index }
        try? modelContext.save()
        TemplateService.syncAllActiveSessions(context: modelContext)
    }
}

private struct PlannedSetEditorRow: View {
    @Bindable var set: PlannedSet
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text("\(set.order + 1)").frame(width: 24)
            OptionalLoadField(loadTenths: $set.loadTenths)
                .frame(maxWidth: .infinity)
            Menu {
                ForEach(WeightUnit.allCases) { unit in
                    Button(unit.rawValue) { changeUnit(to: unit) }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(set.unit.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .frame(width: 52)
            }
            .accessibilityLabel("Единица веса: \(set.unit.rawValue)")
            OptionalRepsField(reps: $set.reps)
                .frame(width: 58)
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .contentShape(Circle())
                .frame(width: 28, height: 28)
                .accessibilityLabel("Удалить подход \(set.order + 1)")
            }
        }
    }

    private func changeUnit(to unit: WeightUnit) {
        guard unit != set.unit else { return }
        if let load = set.loadTenths {
            set.loadTenths = set.unit.converted(loadTenths: load, to: unit)
        }
        set.unit = unit
    }
}
