import SwiftUI
import UIKit

extension View {
    func dismissKeyboardOnTap() -> some View {
        background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
        )
            .scrollDismissesKeyboard(.interactively)
    }
}

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
