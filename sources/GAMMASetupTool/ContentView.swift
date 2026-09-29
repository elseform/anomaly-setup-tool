import SwiftUI

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = AppModel()
    @State private var step: WizardStep = .welcome
    @State private var createButtonSubmitted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            currentStepView
                .id(step)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Divider()
            footer
        }
        .frame(width: Layout.windowWidth, height: Layout.windowHeight)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: step)
        .onChange(of: model.isRunning) { _, isRunning in
            if isRunning {
                step = .create
            }
        }
    }
}

extension ContentView {
    // MARK: - Header

    private var headerText: (title: String, subtitle: String) {
        switch step {
        case .welcome:
            return (
                "Welcome",
                "You need an existing GAMMA installation to continue."
            )
        case .setup:
            return (
                "Options",
                "Choose where the engine comes from and confirm the setup options."
            )
        case .create:
            return (model.createHeaderTitle, model.createHeaderSubtitle)
        case .complete:
            return (WrapperCreatedCopy.title, WrapperCreatedCopy.subtitle)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerText.title)
                    .font(.title2.weight(.semibold))
                Text(headerText.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let progress = stepProgress {
                Text("Step \(progress.current) of \(progress.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, Layout.titleHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .welcome:
            WelcomePage(model: model)
        case .setup:
            SetupPage(model: model)
        case .create:
            CreatePage(
                model: model,
                createButtonSubmitted: $createButtonSubmitted
            )
        case .complete:
            CompletePage(model: model)
        }
    }

    // MARK: - Footer

    private var footerVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? SetupDefaults.toolVersion
    }

    private var footer: some View {
        HStack(spacing: 12) {
            footerMetadata
            Spacer()
            footerBackButton
            footerPrimaryButton
        }
        .padding()
        .background(.bar)
    }

    private var footerMetadata: some View {
        HStack(spacing: 12) {
            Text("v\(footerVersion)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            footerLinks
        }
    }

    private var footerLinks: some View {
        return HStack(spacing: 12) {
            Link(SupportCopy.githubTitle, destination: SupportCopy.githubURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(SupportCopy.githubHelp)

            Link(SupportCopy.discordTitle, destination: SupportCopy.discordURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(SupportCopy.discordHelp)

        }
    }

    @ViewBuilder
    private var footerBackButton: some View {
        if step != .welcome && step != .complete && !model.isRunning && !createButtonSubmitted {
            Button("Back") {
                if let previous = previousStep {
                    step = previous
                }
            }
            .disabled(previousStep == nil)
        }
    }

    @ViewBuilder
    private var footerPrimaryButton: some View {
        switch step {
        case .welcome:
            Button("Continue") {
                continueToNextStep()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(wrapperNameActionsDisabled)
        case .setup:
            createButton(title: "Create wrapper")
        case .create:
            if model.installFailed && !model.isRunning && !createButtonSubmitted {
                createButton(title: "Try again")
            }
        case .complete:
            Button("Show in Finder") {
                model.showCreatedAppAndQuit()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command])
            .help("Reveal the wrapper in Finder and quit GAMMA Setup Tool")
        }
    }

    private func createButton(title: String) -> some View {
        Button(title) {
            startCreate()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(model.isRunning || createButtonSubmitted || !model.setupReady)
    }

    // MARK: - Navigation State

    /// Pages Back/Continue move between. `.create` is reached only by
    /// starting a run; Back from it (after a failure) returns to Options.
    private var visibleSteps: [WizardStep] {
        if step == .complete {
            return []
        }
        return [.welcome, .setup, .create]
    }

    /// The "Step N of M" counter covers only the pages that ask for input.
    private var stepProgress: (current: Int, total: Int)? {
        let counted: [WizardStep] = [.welcome, .setup]
        guard let index = counted.firstIndex(of: step) else { return nil }
        return (index + 1, counted.count)
    }

    private var currentStepIndex: Int? {
        visibleSteps.firstIndex(of: step)
    }

    private var previousStep: WizardStep? {
        guard let index = currentStepIndex, index > 0 else { return nil }
        return visibleSteps[index - 1]
    }

    private var nextStep: WizardStep? {
        guard let index = currentStepIndex, index + 1 < visibleSteps.count else { return nil }
        return visibleSteps[index + 1]
    }

    private var wrapperNameActionsDisabled: Bool {
        !model.wrapperNameIsValid || !model.selectedLaunchExecutableFound
    }

    private func continueToNextStep() {
        guard let next = nextStep else { return }
        step = next
    }

    private func startCreate() {
        createButtonSubmitted = true
        Task {
            let created = await model.createWineEngine()
            createButtonSubmitted = false
            if created {
                step = .complete
            }
        }
    }
}

#if DEBUG
#Preview("GAMMA Setup Tool") {
    ContentView()
}
#endif
