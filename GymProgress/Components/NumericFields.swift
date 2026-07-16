import SwiftUI
import UIKit

extension View {
    func dismissKeyboardOnTap() -> some View {
        background(KeyboardDismissGestureInstaller())
            .scrollDismissesKeyboard(.interactively)
    }
}

/// Observes taps without taking them away from SwiftUI controls. This lets a
/// numeric keyboard close when the user taps elsewhere, while links and buttons
/// keep their normal behaviour.
private struct KeyboardDismissGestureInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let host = uiView.superview else { return }
            context.coordinator.install(on: host)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.remove()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var hostView: UIView?
        private lazy var tapRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )

        func install(on view: UIView) {
            guard hostView !== view else { return }
            remove()
            tapRecognizer.cancelsTouchesInView = false
            tapRecognizer.delaysTouchesBegan = false
            tapRecognizer.delegate = self
            view.addGestureRecognizer(tapRecognizer)
            hostView = view
        }

        func remove() {
            hostView?.removeGestureRecognizer(tapRecognizer)
            hostView = nil
        }

        @objc private func dismissKeyboard() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
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
