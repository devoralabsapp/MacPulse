import AppKit
import SwiftUI
import MacPulseCore

@main
struct MacPulseApp: App {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var cleaner = CleanerModel()
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("showNetworkMenuBar") private var showNetworkMenuBar = true
    @AppStorage("networkRateUnit") private var rateUnit = NetworkRateUnit.bytes.rawValue
    private var l: Localizer { Localizer(language: AppLanguage(rawValue: appLanguage) ?? .system) }
    private var menuBarTitle: String {
        let cpu = l.percent(monitor.snapshot.cpu.usage)
        guard showNetworkMenuBar else { return cpu }
        let unit = NetworkRateUnit(rawValue: rateUnit) ?? .bytes
        return "\(cpu)  ↓ \(l.networkRate(monitor.snapshot.network.download, unit: unit))  ↑ \(l.networkRate(monitor.snapshot.network.upload, unit: unit))"
    }

    var body: some Scene {
        WindowGroup("MacPulse", id: "main") {
            ThemeScope {
                ContentView().environmentObject(monitor).environmentObject(cleaner)
                    .frame(minWidth: 1080, minHeight: 730)
            }.environment(\.localizer, l).environment(\.locale, l.locale)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1220, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(l.text("Theo dõi")) {
                Button(l.text("Cập nhật ngay")) { monitor.sample() }.keyboardShortcut("r")
            }
        }
        MenuBarExtra(isInserted: $showMenuBar) {
            ThemeScope { MenuBarView().environmentObject(monitor) }
                .environment(\.localizer, l).environment(\.locale, l.locale)
        } label: {
            Image(systemName: "waveform.path.ecg")
            Text(menuBarTitle).monospacedDigit()
        }
        .menuBarExtraStyle(.window)
        Settings {
            ThemeScope { PreferencesView().environmentObject(monitor) }
                .environment(\.localizer, l).environment(\.locale, l.locale)
        }
    }
}

struct MenuBarView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.localizer) private var l
    @EnvironmentObject var monitor: SystemMonitor
    @Environment(\.openWindow) var openWindow
    @AppStorage("networkRateUnit") private var rateUnit = NetworkRateUnit.bytes.rawValue
    private var unit: NetworkRateUnit { NetworkRateUnit(rawValue: rateUnit) ?? .bytes }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("MacPulse").font(.headline); Spacer(); Text(l.text("TRỰC TIẾP")).font(.system(size: 9, weight: .bold)).foregroundStyle(theme.success) }
            menuRow("CPU", value: l.percent(monitor.snapshot.cpu.usage), icon: "cpu")
            menuRow(l.text("RAM đang dùng"), value: l.memory(monitor.snapshot.memory.used), icon: "memorychip")
            menuRow(l.text("Ổ đĩa còn trống"), value: l.bytes(monitor.snapshot.disk.available), icon: "internaldrive")
            menuRow(l.text("Pin"), value: l.percent(monitor.snapshot.battery.percent), icon: "battery.75percent")
            if let current = monitor.snapshot.battery.currentMAh {
                Text(l.text("Dung lượng còn lại: %@ mAh", l.number(current))).font(.caption).foregroundStyle(theme.secondaryText)
            }
            Divider()
            menuRow(l.text("Tải xuống"), value: l.networkRate(monitor.snapshot.network.download, unit: unit), icon: "arrow.down")
            menuRow(l.text("Tải lên"), value: l.networkRate(monitor.snapshot.network.upload, unit: unit), icon: "arrow.up")
            Divider()
            Button(l.text("Mở MacPulse")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                .buttonStyle(PrimaryButton()).frame(maxWidth: .infinity)
            Button(l.text("Thoát MacPulse")) { NSApp.terminate(nil) }.font(.caption).foregroundStyle(theme.secondaryText)
        }.padding(22).frame(width: 320).background(theme.surface)
    }
    private func menuRow(_ title: String, value: String, icon: String) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Text(value).monospacedDigit().fontWeight(.medium) }.font(.system(size: 12))
    }
}
