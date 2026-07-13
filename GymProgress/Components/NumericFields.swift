import SwiftUI

struct OptionalLoadField: View {
    @Binding var loadTenths: Int?
    var placeholder = "—"

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
    }
}

struct OptionalRepsField: View {
    @Binding var reps: Int?
    var placeholder = "—"

    var body: some View {
        TextField(placeholder, text: Binding(
            get: { reps.map(String.init) ?? "" },
            set: { reps = Int($0.filter(\.isNumber)) }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
    }
}
