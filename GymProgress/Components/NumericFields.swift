import SwiftUI

struct OptionalLoadField: View {
    @Binding var loadTenths: Int?
    var placeholder = "—"
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: Binding(
            get: { loadTenths?.loadText ?? "" },
            set: { text in
                let normalized = text.replacingOccurrences(of: ",", with: ".")
                loadTenths = Double(normalized).map { Int(($0 * 10).rounded()) }
            }
        ))
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.center)
        .focused($isFocused)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { isFocused = false }
            }
        }
    }
}

struct OptionalRepsField: View {
    @Binding var reps: Int?
    var placeholder = "—"
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: Binding(
            get: { reps.map(String.init) ?? "" },
            set: { reps = Int($0.filter(\.isNumber)) }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .focused($isFocused)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { isFocused = false }
            }
        }
    }
}
