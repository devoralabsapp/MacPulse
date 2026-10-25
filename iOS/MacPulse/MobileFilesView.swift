import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import MacPulseCore

struct MobileFilesView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var model: MobileFilesModel
    var body: some View {
        List {
            Section {
                Label(model.folder?.lastPathComponent ?? l.text("Chưa chọn thư mục"), systemImage: "folder.fill").font(.headline)
                Button(l.text("Chọn thư mục trong Files…")) { model.showImporter = true }
                    .disabled(model.isBusy).accessibilityIdentifier("files.choose")
                if model.folder != nil {
                    if model.isScanning {
                        HStack { ProgressView(); Button(l.text("Dừng quét")) { model.cancelScan() } }
                    } else {
                        Button(l.text(model.hasScanned ? "Quét lại" : "Bắt đầu quét")) { model.scan() }.disabled(model.isBusy)
                    }
                }
                Text(l.text("File lớn ≥ 100 MB hoặc chưa sửa ≥ 180 ngày. Chỉ quét thư mục bạn chọn; không kiểm tra được file có đang được ứng dụng khác sử dụng."))
                    .font(.caption).foregroundStyle(theme.secondaryText)
            }
            if let message = model.message {
                Section { Label(l.render(message), systemImage: "info.circle").font(.footnote).textSelection(.enabled) }
            }
            if !model.warnings.isEmpty {
                Section {
                    ForEach(model.warnings, id: \.self) { warning in
                        Label(l.render(warning), systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(theme.warning)
                    }
                }
            }
            if model.hasScanned {
                Section {
                    if model.visibleFiles.isEmpty { Text(l.text("Không có kết quả phù hợp")).foregroundStyle(theme.secondaryText) }
                    ForEach(model.visibleFiles) { file in fileRow(file) }
                } header: { Text(l.text("%@ file có thể xem lại", l.number(model.files.count))) }
                if !model.selectedFiles.isEmpty {
                    Section {
                        Text(l.text("Đã chọn %@ file · %@", l.number(model.selectedFiles.count), l.bytes(model.selectedSize)))
                        Button(l.text("Chuyển vào khu khôi phục")) { model.pendingAction = .move }
                            .disabled(model.isBusy).accessibilityIdentifier("files.move")
                    }
                }
            }
            if !model.recovery.isEmpty {
                Section {
                    Text(l.text("Khu khôi phục vẫn chiếm dung lượng. Chỉ xóa vĩnh viễn sau khi bạn chắc chắn; không thể khôi phục bằng MacPulse sau bước đó."))
                        .font(.caption).foregroundStyle(theme.warning)
                    ForEach(model.recovery) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text(item.name).font(.headline); Spacer(); Text(l.bytes(item.size)).font(.subheadline).monospacedDigit() }
                            Text(item.relativePath).font(.caption).foregroundStyle(theme.secondaryText).lineLimit(2)
                            HStack {
                                Button(l.text("Khôi phục")) { model.pendingAction = .restore(item) }
                                Spacer()
                                Button(l.text("Xóa vĩnh viễn"), role: .destructive) { model.pendingAction = .delete(item) }
                            }.buttonStyle(.bordered).disabled(model.isBusy)
                        }.padding(.vertical, 6)
                    }
                } header: { Text(l.text("Khu khôi phục")) }
            }
            Section {
                Text(l.text("Không có file nào được chọn sẵn. Tuổi và kích thước không chứng minh file đã hết sử dụng."))
                Text(l.text("Thư mục được chọn có thể thuộc iCloud hoặc nhà cung cấp khác. Di chuyển, khôi phục và xóa trong đó có thể đồng bộ sang thiết bị khác."))
            }.font(.caption).foregroundStyle(theme.secondaryText)
        }
        .searchable(text: $model.query, prompt: l.text("Tìm tên hoặc đường dẫn"))
        .scrollContentBackground(.hidden).background(theme.background)
        .listRowSeparatorTint(theme.border)
        .fileImporter(isPresented: $model.showImporter, allowedContentTypes: [.folder], onCompletion: model.choose)
        .quickLookPreview($model.previewURL)
        .sheet(item: $model.pendingAction) { action in confirmation(action) }
        .overlay { if model.isBusy && !model.isScanning { ProgressView().padding(24).background(theme.surface, in: RoundedRectangle(cornerRadius: 16)) } }
        .accessibilityIdentifier("screen.files")
    }
    private func fileRow(_ file: MobileFile) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { model.toggle(file) } label: {
                Image(systemName: model.selected.contains(file.id) ? "checkmark.circle.fill" : file.blocked ? "hand.raised" : "circle")
                    .font(.title3).foregroundStyle(file.blocked ? theme.danger : theme.accent).frame(minWidth: 32, minHeight: 44)
            }.buttonStyle(.borderless).disabled(file.blocked || model.isBusy).accessibilityLabel(l.text("Chọn %@", file.name))
            VStack(alignment: .leading, spacing: 6) {
                Text(file.name).font(.headline).lineLimit(2)
                Text(l.bytes(file.size) + " · " + file.modified.formatted(.dateTime.day().month().year().locale(l.locale)))
                    .font(.caption).foregroundStyle(theme.secondaryText)
                Text(l.text(file.reasonKey)).font(.caption).foregroundStyle(file.blocked ? theme.danger : theme.warning)
                Button(l.text("Xem trước")) { model.preview(file) }.font(.subheadline).buttonStyle(.borderless).disabled(model.isBusy)
            }
        }.padding(.vertical, 5).listRowBackground(model.selected.contains(file.id) ? theme.selection : theme.surface)
    }
    private func confirmation(_ action: MobileFileAction) -> some View {
        NavigationStack {
            List {
                Section {
                    Text(l.text("Thư mục được chọn có thể thuộc iCloud hoặc nhà cung cấp khác. Di chuyển, khôi phục và xóa trong đó có thể đồng bộ sang thiết bị khác."))
                        .font(.footnote).foregroundStyle(theme.warning)
                    switch action {
                    case .move:
                        Text(l.text("Khu khôi phục vẫn chiếm dung lượng. Bạn có thể khôi phục hoặc xóa vĩnh viễn sau."))
                        ForEach(model.selectedFiles) { file in
                            VStack(alignment: .leading) { Text(file.name); Text(l.bytes(file.size)).font(.caption).foregroundStyle(theme.secondaryText) }
                        }
                    case .restore(let item): Text(item.name); Text(l.text("File trở về vị trí cũ. App không ghi đè file trùng tên."))
                    case .delete(let item): Text(item.name); Text(l.text("Xóa vĩnh viễn file này? MacPulse không thể hoàn tác."))
                    }
                }
                Section {
                    Button(l.text(actionTitle(action)), role: isDeletion(action) ? .destructive : nil) { model.confirm(action) }
                        .accessibilityIdentifier("files.confirm")
                    Button(l.text("Hủy"), role: .cancel) { model.pendingAction = nil }
                }
            }
            .scrollContentBackground(.hidden).background(theme.background)
            .navigationTitle(l.text("Xem lại thao tác")).navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    private func isDeletion(_ action: MobileFileAction) -> Bool { if case .delete = action { return true }; return false }
    private func actionTitle(_ action: MobileFileAction) -> String {
        switch action { case .move: return "Chuyển vào khu khôi phục"; case .restore: return "Khôi phục"; case .delete: return "Xóa vĩnh viễn" }
    }
}
