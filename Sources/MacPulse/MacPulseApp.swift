import AppKit
import SwiftUI
import MacPulseCore

@main
struct MacPulseApp: App {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var cleaner = CleanerModel()
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    private var l: Localizer { Localizer(language: AppLanguage(rawValue: appLanguage) ?? .system) }

    var body: some Scene {
        WindowGroup("MacPulse", id: "main") {
            ContentView().environmentObject(monitor).environmentObject(cleaner)
                .environment(\.localizer, l).environment(\.locale, l.locale)
                .frame(minWidth: 1080, minHeight: 730)
                .preferredColorScheme(.light)
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
            MenuBarView().environmentObject(monitor)
                .environment(\.localizer, l).environment(\.locale, l.locale)
        } label: {
            Image(systemName: "waveform.path.ecg")
            Text(l.percent(monitor.snapshot.cpu.usage))
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
        Settings {
            PreferencesView().environmentObject(monitor)
                .environment(\.localizer, l).environment(\.locale, l.locale)
        }
    }
}

struct PreferencesView: View {
    @Environment(\.localizer) private var l
    @EnvironmentObject var monitor: SystemMonitor
    @AppStorage("refreshInterval") var refreshInterval = 2.0
    @AppStorage("showMenuBar") var showMenuBar = true
    @AppStorage("appLanguage") var appLanguage = AppLanguage.system.rawValue
    var body: some View {
        Form {
            Picker(l.text("Ngôn ngữ"), selection: $appLanguage) {
                Text(l.text("Theo hệ thống")).tag(AppLanguage.system.rawValue)
                Text("Tiếng Việt").tag(AppLanguage.vietnamese.rawValue)
                Text("English").tag(AppLanguage.english.rawValue)
            }
            Text(l.text("Thay đổi ngôn ngữ áp dụng ngay cho cửa sổ, thanh menu và thông báo."))
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Picker(l.text("Cập nhật mỗi"), selection: $refreshInterval) {
                Text(l.text("1 giây")).tag(1.0)
                Text(l.text("2 giây")).tag(2.0)
                Text(l.text("5 giây")).tag(5.0)
            }.onChange(of: refreshInterval) { _, _ in monitor.restart() }
            Toggle(l.text("Hiển thị CPU trên thanh menu"), isOn: $showMenuBar)
            Text(l.text("Dữ liệu được đọc trực tiếp trên máy. MacPulse không tải dữ liệu lên mạng và không tự động xóa file."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(width: 500)
    }
}

struct MenuBarView: View {
    @Environment(\.localizer) private var l
    @EnvironmentObject var monitor: SystemMonitor
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("MacPulse").font(.headline); Spacer(); Text(l.text("TRỰC TIẾP")).font(.system(size: 9, weight: .bold)).foregroundStyle(.green) }
            menuRow("CPU", value: l.percent(monitor.snapshot.cpu.usage), icon: "cpu")
            menuRow(l.text("RAM đang dùng"), value: l.memory(monitor.snapshot.memory.used), icon: "memorychip")
            menuRow(l.text("Ổ đĩa còn trống"), value: l.bytes(monitor.snapshot.disk.available), icon: "internaldrive")
            menuRow(l.text("Pin"), value: l.percent(monitor.snapshot.battery.percent), icon: "battery.75percent")
            if let current = monitor.snapshot.battery.currentMAh {
                Text(l.text("Dung lượng còn lại: %@ mAh", l.number(current))).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Button(l.text("Mở MacPulse")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            Button(l.text("Thoát MacPulse")) { NSApp.terminate(nil) }.font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 300)
    }
    private func menuRow(_ title: String, value: String, icon: String) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Text(value).monospacedDigit().fontWeight(.medium) }.font(.system(size: 12))
    }
}
