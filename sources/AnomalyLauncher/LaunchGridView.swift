import SwiftUI
import AppKit

/// The first sidebar page: one tile per thing the wrapper can start.
struct LaunchGridView: View {
    let model: ConfiguratorModel
    let launcher: LaunchController

    private let columns = [GridItem(.adaptive(minimum: Layout.tileWidth), spacing: 24, alignment: .top)]
    private var isLocked: Bool { !model.canEdit || launcher.isRunning }

    var body: some View {
        let modOrganizerEntries = model.modOrganizerEntries
        let customEntries = model.customEntries
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let error = model.loadError ?? model.saveError ?? launcher.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(StatusTone.error.color)
                }
                if modOrganizerEntries.isEmpty && customEntries.isEmpty {
                    ContentUnavailableView(
                        "Nothing to launch",
                        systemImage: "play.slash",
                        description: Text("Set ModOrganizer.exe or a custom .exe in Launch options.")
                    )
                } else {
                    grid(modOrganizerEntries)
                    grid(customEntries)
                }
            }
            .padding(24)
        }
    }

    /// One row of tiles; wraps when more tiles than fit. An empty list draws nothing.
    @ViewBuilder
    private func grid(_ entries: [LaunchEntry]) -> some View {
        if !entries.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                ForEach(entries) { entry in
                    Button { launcher.launch(entry, model: model) } label: { LaunchTile(entry: entry) }
                        .buttonStyle(LaunchTileButtonStyle())
                        .disabled(isLocked)
                }
            }
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

/// The tile artwork compiled from the .icon documents into the wrapper's
/// Resources, with a drawn rounded square when the wrapper predates them.
private struct LaunchIcon: View {
    let kind: LaunchEntry.Kind

    private var artworkName: String {
        switch kind {
        case .modOrganizer: "mo2"
        case .anomalyDX11, .anomalyDX11AVX: "anomalyexes"
        case .custom: "custom"
        }
    }

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
        artwork
            .frame(width: Layout.tileIconSize, height: Layout.tileIconSize)
            .overlay(alignment: .bottomTrailing) {
                if kind == .anomalyDX11AVX {
                    Text("AVX")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.55), in: .capsule)
                        .foregroundStyle(.white)
                        .padding(.trailing, 8)
                        .padding(.bottom, 10)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = TileArtwork.image(named: artworkName) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: Layout.tileIconSize * 0.225, style: .continuous)
                .fill(tint.gradient)
                .padding(Layout.tileIconSize * 0.1)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: Layout.tileIconSize * 0.4))
                        .foregroundStyle(.white)
                }
        }
    }
}

private struct LaunchTileButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.7 : 1)
    }
}
