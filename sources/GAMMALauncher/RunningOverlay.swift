import SwiftUI

/// Covers the whole window while a launched program is running. The window
/// unlocks by itself when that program exits.
struct RunningOverlay: View {
    let label: String

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.35))
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text("Wrapper is running")
                    .font(.title3.bold())
                Text("\(label) was started. Settings unlock when it exits.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
    }
}
