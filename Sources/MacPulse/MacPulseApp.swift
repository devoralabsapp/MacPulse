import AppKit
import SwiftUI
import MacPulseCore

@main
struct MacPulseApp: App {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var cleaner = CleanerModel()
    @AppStorage("showMenuBar") private var showMenuBar = true

    var body: some Scene {
        WindowGroup("MacPulse", id: "main") {
            ContentView().environmentObject(monitor).environmentObject(cleaner)
                .frame(minWidth: 1080, minHeight: 730)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1220, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Theo dõi") {
                Button("Cập nhật ngay") { monitor.sample() }.keyboardShortcut("r")
            }
        }
        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarView().environmentObject(monitor)
        } label: {
            Image(systemName: "waveform.path.ecg")
            Text(DisplayFormat.percent(monitor.snapshot.cpu.usage))
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
        Settings {
            PreferencesView().environmentObject(monitor)
        }
    }
}

struct PreferencesView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @AppStorage("refreshInterval") var refreshInterval = 2.0
    @AppStorage("showMenuBar") var showMenuBar = true
    var body: some View {
        Form {
            Picker("Cập nhật mỗi", selection: $refreshInterval) {
                Text("1 giây").tag(1.0)
                Text("2 giây").tag(2.0)
                Text("5 giây").tag(5.0)
            }.onChange(of: refreshInterval) { _, _ in monitor.restart() }
            Toggle("Hiển thị CPU trên thanh menu", isOn: $showMenuBar)
            Text("Dữ liệu được đọc trực tiếp trên máy. MacPulse không tải dữ liệu lên mạng và không tự động xóa file.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(width: 430)
    }
}

struct MenuBarView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("MacPulse").font(.headline); Spacer(); Text("TRỰC TIẾP").font(.system(size: 9, weight: .bold)).foregroundStyle(.green) }
            menuRow("CPU", value: DisplayFormat.percent(monitor.snapshot.cpu.usage), icon: "cpu")
            menuRow("RAM đang dùng", value: DisplayFormat.bytes(monitor.snapshot.memory.used), icon: "memorychip")
            menuRow("Ổ đĩa còn trống", value: DisplayFormat.bytes(monitor.snapshot.disk.available), icon: "internaldrive")
            menuRow("Pin", value: DisplayFormat.percent(monitor.snapshot.battery.percent), icon: "battery.75percent")
            if let current = monitor.snapshot.battery.currentMAh {
                Text("Dung lượng còn lại: \(DisplayFormat.number(current)) mAh").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Button("Mở MacPulse") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            Button("Thoát MacPulse") { NSApp.terminate(nil) }.font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 300)
    }
    private func menuRow(_ title: String, value: String, icon: String) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Text(value).monospacedDigit().fontWeight(.medium) }.font(.system(size: 12))
    }
}
