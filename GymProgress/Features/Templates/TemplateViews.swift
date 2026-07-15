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
        .onChange(of: template.name) { _, _ in
            TemplateService.syncPlannedSchedules(for: template, context: modelContext)
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
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = template.sortedSlots
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, slot) in ordered.enumerated() { slot.order = index }
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet) {
        let ordered = template.sortedSlots
        for index in offsets {
            let slot = ordered[index]
            template.slots.removeAll { $0.id == slot.id }
            modelContext.delete(slot)
        }
        try? modelContext.save()
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
        .sheet(isPresented: $showCatalog) {
            CatalogPickerView { item in
                let sets = (0..<3).map {
                    PlannedSet(order: $0, loadTenths: nil, reps: nil, unit: item.defaultUnit)
                }
                slot.variants.append(TemplateVariant(catalogID: item.id, plannedSets: sets))
                try? modelContext.save()
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
    }
}

private struct VariantEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var variant: TemplateVariant

    var body: some View {
        Form {
            Section("Отдых") {
                Stepper("\(variant.restSeconds) секунд", value: $variant.restSeconds, in: 30...300, step: 15)
            }
            Section("Подходы") {
                Text("Ориентир для следующей тренировки: укажите вес и повторы. Можно оставить поля пустыми.")
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
    }

    private func delete(_ set: PlannedSet) {
        variant.plannedSets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        for (index, set) in variant.sortedSets.enumerated() { set.order = index }
        try? modelContext.save()
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
