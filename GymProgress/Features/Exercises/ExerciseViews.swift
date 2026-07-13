import SwiftUI

struct ExerciseListView: View {
    @State private var search = ""
    @State private var selectedMuscle = "Все"

    private var muscles: [String] {
        ["Все"] + Array(Set(ExerciseCatalog.shared.items.flatMap(\.primaryMuscles))).sorted()
    }

    private var filteredItems: [ExerciseCatalogItem] {
        ExerciseCatalog.shared.items.filter { item in
            let matchesMuscle = selectedMuscle == "Все" || item.primaryMuscles.contains(selectedMuscle)
            let matchesSearch = search.isEmpty
                || item.name.localizedCaseInsensitiveContains(search)
                || item.equipment.localizedCaseInsensitiveContains(search)
            return matchesMuscle && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Мышца", selection: $selectedMuscle) {
                        ForEach(muscles, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section {
                    ForEach(filteredItems) { item in
                        NavigationLink {
                            ExerciseDetailView(item: item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 38, height: 38)
                                    .background(AppTheme.accent.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.headline)
                                    Text(item.primaryMuscles.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                        }
                    }
                } header: {
                    Text("\(filteredItems.count) упражнений")
                }
            }
            .searchable(text: $search, prompt: "Название или оборудование")
            .navigationTitle("Упражнения")
        }
    }
}

struct ExerciseDetailView: View {
    let item: ExerciseCatalogItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AnimatedGIFView(name: item.gifName)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Что работает")
                        .font(.headline)
                    Text(item.primaryMuscles.joined(separator: ", "))
                    if !item.secondaryMuscles.isEmpty {
                        Text("Дополнительно: \(item.secondaryMuscles.joined(separator: ", "))")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Label(item.equipment, systemImage: "dumbbell")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Техника")
                        .font(.headline)
                    ForEach(Array(item.technique.enumerated()), id: \.offset) { index, cue in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(AppTheme.accent)
                                .clipShape(Circle())
                            Text(cue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()

                Text("© Gym visual — https://gymvisual.com/")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
