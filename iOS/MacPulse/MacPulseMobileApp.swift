import SwiftUI
import MacPulseCore

@main
struct MacPulseMobileApp: App {
    @StateObject private var monitor = MobileMonitor()
    @StateObject private var files = MobileFilesModel()
    @Environment(\.scenePhase) private var phase
    @AppStorage("appLanguage") private var language = AppLanguage.system.rawValue
    private var l: Localizer { Localizer(language: AppLanguage(rawValue: language) ?? .system) }
    var body: some Scene {
        WindowGroup {
            ThemeScope { MobileRootView() }
                .environmentObject(monitor).environmentObject(files)
                .environment(\.localizer, l).environment(\.locale, l.locale)
                .onChange(of: phase, initial: true) { _, value in
                    if value == .active { monitor.resume() } else { monitor.pause() }
                }
        }
    }
}

enum MobilePage: String, CaseIterable, Identifiable {
    case overview, network, files, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Tổng quan"
        case .network: return "Mạng"
        case .files: return "Dọn dẹp"
        case .settings: return "Cài đặt"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .network: return "network"
        case .files: return "folder"
        case .settings: return "gearshape"
        }
    }
}

struct MobileRootView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @SceneStorage("mobilePage") private var pageRaw = MobilePage.overview.rawValue
    private var page: Binding<MobilePage> {
        Binding(get: { MobilePage(rawValue: pageRaw) ?? .overview }, set: { pageRaw = $0.rawValue })
    }
    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    List(MobilePage.allCases) { item in
                        Button { page.wrappedValue = item } label: {
                            Label(l.text(item.title), systemImage: item.icon)
                                .foregroundStyle(page.wrappedValue == item ? theme.accent : theme.text)
                                .padding(.vertical, 6)
                        }.accessibilityIdentifier("page.\(item.title == "Dọn dẹp" ? "cleanup" : item.rawValue)")
                        .listRowBackground(page.wrappedValue == item ? theme.selection : Color.clear)
                    }.scrollContentBackground(.hidden).background(theme.sidebar).navigationTitle("MacPulse")
                } detail: { navigation(page.wrappedValue) }
            } else {
                TabView(selection: page) {
                    ForEach(MobilePage.allCases) { item in
                        navigation(item).tabItem { Label(l.text(item.title), systemImage: item.icon) }.tag(item)
                    }
                }
            }
        }.tint(theme.accent)
    }
    private func navigation(_ item: MobilePage) -> some View {
        NavigationStack {
            Group {
                switch item {
                case .overview: MobileOverviewView()
                case .network: MobileNetworkView()
                case .files: MobileFilesView()
                case .settings: MobileSettingsView()
                }
            }
            .navigationTitle(l.text(item.title)).background(theme.background)
            .toolbarBackground(theme.background, for: .navigationBar)
        }
    }
}
