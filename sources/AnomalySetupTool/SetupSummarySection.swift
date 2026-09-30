import SwiftUI

/// The short list on the Welcome page of what setup is going to do.
struct SetupSummarySection: View {
    let model: AppModel

    var body: some View {
        Section {
            Label {
                Text("Create the wrapper in ~/Applications")
            } icon: {
                Image(systemName: "app.badge.checkmark")
                    .foregroundStyle(.tint)
            }
            Label {
                Text(model.usesLocalEngine
                     ? "Use the local wine engine archive"
                     : "Download the latest wine engine")
            } icon: {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.tint)
            }
            Label {
                Text("Set up the wrapper for your Anomaly installation")
            } icon: {
                Image(systemName: "play.circle")
                    .foregroundStyle(.tint)
            }
        } header: {
            Text("What setup will do")
        }
    }
}
