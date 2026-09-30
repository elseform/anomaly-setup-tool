import SwiftUI

/// The category list. A badge counts the settings that differ from what a
/// new install starts with.
struct LauncherSidebar: View {
    let model: ConfiguratorModel
    @Binding var selection: SettingCategory

    var body: some View {
        List(selection: Binding<SettingCategory?>(get: { selection }, set: { if let category = $0 { selection = category } })) {
            section(nil, .home)
            section("Game", .game)
            section("Advanced", .advanced)
            section(nil, .info)
        }
        .toolbar(removing: .sidebarToggle)
        // Must come after .toolbar(removing:), which otherwise drops the width.
        .navigationSplitViewColumnWidth(Layout.sidebarWidth)
    }

    private func section(_ title: String?, _ section: SidebarSection) -> some View {
        Section {
            ForEach(SettingCategory.allCases.filter { $0.sidebarSection == section }) { category in
                Label(category.title, systemImage: category.systemImage)
                    .badge(model.changedCount(in: category))
            }
        } header: {
            if let title { Text(title) }
        }
    }
}
