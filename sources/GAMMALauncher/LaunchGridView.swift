import SwiftUI

/// The first sidebar page: one tile per thing the wrapper can start.
struct LaunchGridView: View {
    let model: ConfiguratorModel
    let launcher: LaunchController

    private let columns = [GridItem(.adaptive(minimum: Layout.tileWidth), spacing: 24, alignment: .top)]
    private var isLocked: Bool { !model.canEdit || launcher.isLaunching }

    var body: some View {
        let entries = model.launchEntries
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = model.loadError ?? model.saveError ?? launcher.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(StatusTone.error.color)
                }
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Nothing to launch",
                        systemImage: "play.slash",
                        description: Text("Set ModOrganizer.exe or a custom .exe in Launch options.")
                    )
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                        ForEach(entries) { entry in
                            Button { launcher.launch(entry, model: model) } label: { LaunchTile(entry: entry) }
                                .buttonStyle(LaunchTileButtonStyle())
                                .disabled(isLocked)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct LaunchTile: View {
    let entry: LaunchEntry

    var body: some View {
        VStack(spacing: 8) {
            LaunchIcon(kind: entry.kind)
            Text(entry.label)
                .font(.callout)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(width: Layout.tileWidth)
        .contentShape(.rect)
    }
}

/// Drawn stand-ins for real artwork: a rounded square with a symbol.
private struct LaunchIcon: View {
    let kind: LaunchEntry.Kind

    private var symbol: String {
        switch kind {
        case .modOrganizer: "shippingbox.fill"
        case .anomalyDX11, .anomalyDX11AVX: "scope"
        case .custom: "macwindow"
        }
    }

    private var tint: Color {
        switch kind {
        case .modOrganizer: .indigo
        case .anomalyDX11, .anomalyDX11AVX: .orange
        case .custom: .gray
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Layout.tileIconSize * 0.225, style: .continuous)
            .fill(tint.gradient)
            .frame(width: Layout.tileIconSize, height: Layout.tileIconSize)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: Layout.tileIconSize * 0.45))
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .bottomTrailing) {
                if kind == .anomalyDX11AVX {
                    Text("AVX")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.55), in: .capsule)
                        .foregroundStyle(.white)
                        .padding(5)
                }
            }
            .accessibilityHidden(true)
    }
}

private struct LaunchTileButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.7 : 1)
    }
}
