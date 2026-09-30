import SwiftUI

#if SWIFT_PACKAGE
import AnomalySetupCore
#endif

enum WizardStep {
    case welcome
    case setup
    case create
    case complete
}

/// A row's name with an optional one-line description underneath, as the
/// launcher's settings rows show them.
struct RowLabel: View {
    let title: String
    var detail: String?
    /// For file paths: one line, shortened in the middle, selectable.
    var detailIsPath = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(detailIsPath ? 1 : nil)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: !detailIsPath)
            }
        }
    }
}

/// Explanatory text under a form section, in the launcher's footer style.
struct SectionNote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The rows inside an open disclosure, spaced apart and clear of its title.
struct DisclosureBody<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(.top, 8)
    }
}

extension View {
    /// The grouped form every page uses, with room above the first section.
    func pageForm() -> some View {
        formStyle(.grouped)
            .contentMargins(.top, 8, for: .scrollContent)
    }
}

/// One line saying what setup does (or did) to ModOrganizer's USVFS files.
struct USVFSStatusRow: View {
    let outcome: USVFSUpdater.Outcome?
    var finished = false

    var body: some View {
        if let outcome {
            Label {
                Text(message(for: outcome))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: symbol(for: outcome))
                    .foregroundStyle(tint(for: outcome))
            }
            .font(.callout)
            .help("USVFS is the virtual file system Mod Organizer uses to load mods.")
        }
    }

    private func message(for outcome: USVFSUpdater.Outcome) -> String {
        switch outcome {
        case .notModOrganizer:
            return "USVFS binaries \(finished ? "were" : "won't be") updated, selected target is not Mod Organizer."
        case .upToDate:
            return "USVFS binaries \(finished ? "were" : "are") already up to date."
        case .updated(_, let replaced, _):
            let files = replaced.count == 1 ? "1 file" : "\(replaced.count) files"
            return finished
                ? "Updated USVFS binaries (\(files)). The originals were backed up to \(USVFSUpdater.backupFolderName) in the Mod Organizer folder."
                : "USVFS binaries will be updated (\(files)). The originals are backed up first."
        }
    }

    private func symbol(for outcome: USVFSUpdater.Outcome) -> String {
        switch outcome {
        case .notModOrganizer: return "minus.circle"
        case .upToDate: return "checkmark.circle.fill"
        case .updated: return finished ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    private func tint(for outcome: USVFSUpdater.Outcome) -> Color {
        switch outcome {
        case .notModOrganizer: return .secondary
        case .upToDate: return .green
        case .updated: return finished ? .green : .orange
        }
    }
}
