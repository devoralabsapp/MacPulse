import AppKit
import SwiftUI
import UniformTypeIdentifiers
import MacPulseCore

@MainActor
private final class ConnectedBatteryModel: ObservableObject {
    @Published var devices: [USBBatteryDevice] = []
    @Published var selectedID = ""
    @Published var report: DeviceBatteryReport?
    @Published var busy = false
    @Published var scanned = false
    @Published var message: LocalizedMessage?
    @Published var label = "iPhone / iPad"

    func scan() {
        guard !busy else { return }
        busy = true; message = nil; report = nil
        Task {
            let result = await Task.detached { Result { try USBBatteryReader().devices() } }.value
            switch result {
            case let .success(devices):
                self.devices = devices
                if !devices.contains(where: { $0.id == selectedID }) { selectedID = devices.first?.id ?? "" }
            case let .failure(error):
                devices = []; selectedID = ""; message = (error as? BatteryReportError ?? .commandFailed).message
            }
            scanned = true; busy = false
        }
    }
    func read() {
        guard !busy, let device = devices.first(where: { $0.id == selectedID }) else { return }
        busy = true; message = nil; report = nil
        Task {
            let result = await Task.detached { Result { try USBBatteryReader().read(device) } }.value
            switch result {
            case let .success(value): report = value
            case let .failure(error): message = (error as? BatteryReportError ?? .commandFailed).message
            }
            busy = false
        }
    }
    func export(localizer l: Localizer) {
        guard var report else { return }
        report.deviceLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = try? BatteryReportCodec.encode(report) else {
            message = LocalizedMessage("Nhãn thiết bị cần từ 1 đến 80 ký tự, không chứa ký tự điều khiển."); return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "MacPulse-Battery.json"
        panel.title = l.text("Xuất báo cáo pin")
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do { try data.write(to: url, options: .atomic) }
            catch { self?.message = LocalizedMessage("Không lưu được báo cáo pin. Hãy chọn vị trí khác.") }
        }
    }
}

struct ConnectedBatteryView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @StateObject private var model = ConnectedBatteryModel()
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(title: "Pin iPhone / iPad qua USB", subtitle: "Kết nối thiết bị, mở khóa và chọn Tin cậy máy Mac này.")
                HStack(spacing: 12) {
                    Picker(l.text("Thiết bị USB"), selection: $model.selectedID) {
                        if model.devices.isEmpty { Text(l.text("Chưa có thiết bị")).tag("") }
                        ForEach(Array(model.devices.enumerated()), id: \.element.id) { index, device in
                            Text("iPhone / iPad \(index + 1) · …\(device.shortID)").tag(device.id)
                        }
                    }.frame(maxWidth: 400).disabled(model.busy || model.devices.isEmpty)
                        .onChange(of: model.selectedID) { _, _ in model.report = nil }
                    Button(l.text("Tìm thiết bị")) { model.scan() }.disabled(model.busy)
                    Button(l.text("Đọc pin qua USB")) { model.read() }
                        .buttonStyle(PrimaryButton()).disabled(model.busy || model.selectedID.isEmpty)
                    if model.busy { ProgressView().controlSize(.small) }
                }
                if model.scanned && model.devices.isEmpty && model.message == nil {
                    Text(l.text("Chưa thấy iPhone/iPad qua USB. Kiểm tra cáp, mở khóa và chọn Tin cậy.")).font(.callout)
                }
                if let message = model.message {
                    Label(l.render(message), systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(theme.warning)
                }
                DisclosureGroup(l.text("Thiết lập lần đầu & chuyển báo cáo sang iOS")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(l.text("Cài công cụ USB bằng Homebrew trong Terminal:"))
                        Text("brew install libimobiledevice").font(.callout.monospaced()).textSelection(.enabled)
                        Link(l.text("Hướng dẫn Homebrew"), destination: URL(string: "https://formulae.brew.sh/formula/libimobiledevice")!)
                        Text(l.text("MacPulse tìm công cụ tại /opt/homebrew/bin hoặc /usr/local/bin. Công cụ được cài riêng, không đóng gói trong app."))
                        Text(l.text("Chọn đúng thiết bị khi có nhiều iPhone/iPad. Xuất JSON, chuyển bằng AirDrop hoặc Files rồi chọn Nhập báo cáo pin trên iOS. Báo cáo không chứa UDID hay số sê-ri; nhãn thiết bị do bạn đặt."))
                    }.font(.caption).foregroundStyle(theme.secondaryText).padding(.top, 8)
                }
            }
        }
        if let report = model.report {
            DeviceBatteryReportPanel(report: report)
            Panel {
                HStack(spacing: 14) {
                    TextField(l.text("Nhãn thiết bị"), text: $model.label).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                    Button(l.text("Xuất báo cáo pin")) { model.export(localizer: l) }.buttonStyle(PrimaryButton())
                    Text(l.text("Chỉ thông tin pin, nguồn và thời điểm đọc.")).font(.caption).foregroundStyle(theme.secondaryText)
                }
            }
        }
    }
}
