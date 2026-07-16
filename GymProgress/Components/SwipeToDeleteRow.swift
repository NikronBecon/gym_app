import SwiftUI

/// A scroll-view counterpart of List's native trailing delete action.
/// It is used where embedding a List would break the screen layout.
struct SwipeToDeleteRow<Content: View>: View {
    let isEnabled: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isRevealed = false

    var body: some View {
        ZStack(alignment: .trailing) {
            if isEnabled {
                Button(role: .destructive) {
                    withAnimation(.snappy) {
                        onDelete()
                    }
                } label: {
                    Label("Удалить", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: actionWidth, height: 52)
                }
                .buttonStyle(.plain)
                .background(.red)
                .clipShape(Capsule())
                .padding(.trailing, 2)
            }

            content()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                // The content must be opaque while closed; otherwise the
                // delete control behind it leaks through before any swipe.
                .background(AppTheme.card)
                .offset(x: offset)
                .allowsHitTesting(!isRevealed)
                .simultaneousGesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actionWidth: CGFloat { 92 }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard isEnabled else { return }
                offset = min(0, max(-actionWidth, value.translation.width))
            }
            .onEnded { value in
                guard isEnabled else { return }
                withAnimation(.snappy) {
                    isRevealed = value.translation.width < -(actionWidth * 0.45)
                    offset = isRevealed ? -actionWidth : 0
                }
            }
    }
}
