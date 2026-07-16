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
                    Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.red)
                    .clipShape(Circle())
                    .scaleEffect(0.78 + 0.22 * actionProgress, anchor: .trailing)
                    .opacity(actionProgress)
                }
                .buttonStyle(.plain)
                .frame(width: actionWidth, alignment: .trailing)
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
        }
        .contentShape(Rectangle())
        .simultaneousGesture(swipeGesture)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actionWidth: CGFloat { 52 }

    private var actionProgress: CGFloat {
        min(1, max(0, -offset / actionWidth))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard isEnabled else { return }
                let startingOffset: CGFloat = isRevealed ? -actionWidth : 0
                offset = min(0, max(-actionWidth, startingOffset + value.translation.width))
            }
            .onEnded { _ in
                guard isEnabled else { return }
                withAnimation(.snappy) {
                    isRevealed = offset < -(actionWidth * 0.5)
                    offset = isRevealed ? -actionWidth : 0
                }
            }
    }
}
