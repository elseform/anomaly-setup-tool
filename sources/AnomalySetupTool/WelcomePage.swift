import SwiftUI
import AppKit

#if SWIFT_PACKAGE
import AnomalySetupCore
#endif

/// First page: pick the launch executable, then name the app. The name
/// field appears only once an executable is picked, replacing the picker
/// with a one-line summary of the choice.
struct WelcomePage: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var appNameIsFocused: Bool

    var body: some View {
        Form {
            Section {
                if model.selectedLaunchExecutableFound {
                    pickedLocation
                } else {
                    locationPicker
                }
            }
            if model.selectedLaunchExecutableFound {
                appNameSection
            }
            SetupSummarySection(model: model)
        }
        .pageForm()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.selectedLaunchExecutableFound)
        .onChange(of: model.selectedLaunchExecutableFound) { _, found in
            appNameIsFocused = found
        }
    }

    // MARK: - Location

    private var locationPicker: some View {
        LabeledContent {
            Button("Choose…", action: model.chooseLaunchExecutable)
                .buttonStyle(.borderedProminent)
                .help("Pick ModOrganizer.exe, or another Windows program to launch instead")
        } label: {
            Text("Select ModOrganizer’s executable file")
        }
    }

    @ViewBuilder
    private var pickedLocation: some View {
        LabeledContent {
            Button("Change…", action: model.chooseLaunchExecutable)
                .accessibilityLabel("Change launch executable")
        } label: {
            RowLabel(
                title: URL(fileURLWithPath: model.selectedLaunchExecutablePath).lastPathComponent,
                detail: model.selectedLaunchExecutablePath,
                detailIsPath: true
            )
        }
    }

    // MARK: - App Name

    private var appNameSection: some View {
        Section {
            TextField("Wrapper name", text: $model.appName)
                .focused($appNameIsFocused)
            LabeledContent {
                if model.outputAppAlreadyExists {
                    Button("Show existing wrapper", action: model.showExistingApp)
                }
            } label: {
                RowLabel(title: "Saved as", detail: model.outputAppPath, detailIsPath: true)
            }
        } footer: {
            if !model.wrapperNameValidationMessage.isEmpty {
                Text(model.wrapperNameValidationMessage)
                    .foregroundStyle(SetupStatusTone.error.color)
            }
        }
    }
}
