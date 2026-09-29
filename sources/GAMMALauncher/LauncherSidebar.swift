import SwiftUI

/// The category list. A badge counts the settings that differ from what a
/// new install starts with.
struct LauncherSidebar: View {
    let model: ConfiguratorModel
    @Binding var selection: SettingCategory

    var body: some View {
        List(selection: Binding<SettingCategory?>(get: { selection }, set: { if let category = $0 { selection = category } })) {
            section("Game", advanced: false)
            section("Advanced", advanced: true)
        }
        .toolbar(removing: .sidebarToggle)
        // Must come after .toolbar(removing:), which otherwise drops the width.
        .navigationSplitViewColumnWidth(Layout.sidebarWidth)
    }

    private func section(_ title: String, advanced: Bool) -> some View {
        Section(title) {
            ForEach(SettingCategory.allCases.filter { $0.isAdvanced == advanced }) { category in
                Label(category.title, systemImage: category.systemImage)
                    .badge(model.changedCount(in: category))
            }
        }
    }
}
