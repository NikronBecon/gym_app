import SwiftUI

struct CatalogPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let onSelect: (ExerciseCatalogItem) -> Void

    private var items: [ExerciseCatalogItem] {
        guard !search.isEmpty else { return ExerciseCatalog.shared.items }
        return ExerciseCatalog.shared.items.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.primaryMuscles.joined(separator: " ").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List(items) { item in
                Button {
                    onSelect(item)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .foregroundStyle(AppTheme.text)
                        Text(item.primaryMuscles.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .searchable(text: $search, prompt: "Название или мышца")
            .navigationTitle("Выберите упражнение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
