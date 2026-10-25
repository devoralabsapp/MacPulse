import AppKit
import SwiftUI
import MacPulseCore
import UniformTypeIdentifiers

struct CleanerView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @EnvironmentObject var cleaner: CleanerModel
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 17) {
                HStack(spacing: 15) {
                    Image(systemName: "folder.fill").font(theme.font(size: 25)).foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(cleaner.folder.lastPathComponent).font(theme.font(size: 14, weight: .semibold))
                        Text(cleaner.folder.path).font(theme.font(size: 10)).foregroundStyle(theme.secondaryText).lineLimit(1).truncationMode(.middle).help(cleaner.folder.path)
                    }
                    Spacer()
                    Button(l.text("Chọn thư mục…")) { cleaner.chooseFolder(localizer: l) }.controlSize(.large).disabled(cleaner.isScanning || cleaner.isTrashing)
                    if cleaner.isScanning {
                        Button { cleaner.cancel() } label: { Label(l.text("Dừng quét"), systemImage: "stop.fill") }.buttonStyle(PrimaryButton(secondary: true))
                    } else {
                        Button { cleaner.scan() } label: { Label(cleaner.hasScanned ? l.text("Quét lại") : l.text("Bắt đầu quét"), systemImage: "magnifyingglass") }.buttonStyle(PrimaryButton()).disabled(cleaner.isTrashing)
                    }
                }
                Divider()
                HStack {
                    Toggle(l.text("Quét thêm cache và nhật ký người dùng (cũ hơn 30 ngày)"), isOn: $cleaner.includeCaches)
                        .font(theme.font(size: 11)).toggleStyle(.checkbox).disabled(cleaner.isScanning || cleaner.isTrashing)
                    Spacer()
                    Label(l.text("Xem trước khi xóa"), systemImage: "checkmark.shield").font(theme.font(size: 10)).foregroundStyle(theme.success)
                }
                Text(l.text("File lớn ≥ 100 MB · Chưa chỉnh sửa ≥ 180 ngày. Ngày sửa đổi không xác định được file còn sử dụng hay không."))
                    .font(theme.font(size: 10)).foregroundStyle(theme.secondaryText)
                Text(l.text("Mức đánh giá là gợi ý, không bảo đảm file đã hết sử dụng. Nhãn ít rủi ro chỉ áp dụng cho một số cache/log cũ qua kiểm tra."))
                    .font(theme.font(size: 10)).foregroundStyle(theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
        if let message = cleaner.message {
            Label(l.render(message), systemImage: "info.circle").font(theme.font(size: 12)).foregroundStyle(theme.accent).textSelection(.enabled)
        }
        if !cleaner.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(cleaner.warnings, id: \.self) { warning in Label(l.render(warning), systemImage: "exclamationmark.triangle").font(theme.font(size: 11)).foregroundStyle(theme.warning).textSelection(.enabled) }
            }
        }
        if cleaner.isScanning {
            Panel {
                VStack(spacing: 18) {
                    ProgressView().controlSize(.large)
                    Text(l.text("Đang kiểm tra file đang mở và thông tin file…")).font(theme.font(size: 16, weight: .medium))
                    Text(l.text("Chỉ đọc thông tin file, không mở nội dung và không tự động xóa.")).font(theme.font(size: 12)).foregroundStyle(theme.secondaryText)
                }.frame(maxWidth: .infinity).padding(.vertical, 64)
            }
        } else if !cleaner.hasScanned {
            emptyState(icon: "sparkles", title: l.text("Thêm khoảng trống. Bớt bận tâm."), text: l.text("Bắt đầu quét để xem file lớn, file lâu chưa sửa và cache cũ.\nKhông có mục nào được chọn sẵn để xóa."))
        } else {
            results
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SectionTitle(title: l.text("%@ file có thể xem lại", l.number(cleaner.files.count)), subtitle: l.text("%@ dung lượng file · đã xem %@ mục", l.bytes(cleaner.totalSize), l.number(cleaner.inspected)))
                Spacer()
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(theme.secondaryText)
                    TextField(l.text("Tìm tên hoặc đường dẫn"), text: $cleaner.query).textFieldStyle(.plain)
                }.font(theme.font(size: 11)).padding(10).frame(width: 225).background(theme.surface, in: RoundedRectangle(cornerRadius: 9))
            }
            HStack(spacing: 8) {
                filterButton(l.text("Tất cả"), category: nil)
                ForEach(CleanupCategory.allCases) { category in filterButton(l.text(category.title), category: category) }
            }
            HStack(spacing: 16) {
                ForEach(CleanupRisk.allCases) { risk in
                    HStack(spacing: 5) {
                        RiskBadge(risk: risk)
                        Text(l.number(cleaner.count(risk))).font(theme.font(size: 11, weight: .medium)).monospacedDigit()
                    }
                }
                Spacer()
                Picker(l.text("Đánh giá"), selection: $cleaner.riskFilter) {
                    Text(l.text("Tất cả mức đánh giá")).tag(nil as CleanupRisk?)
                    ForEach(CleanupRisk.allCases) { risk in Text(l.text(risk.title)).tag(Optional(risk)) }
                }.font(theme.font(size: 11)).frame(width: 200)
            }
            HStack {
                Text(l.text("Cache/log cũ thường ít rủi ro hơn tài liệu cá nhân. Bật quét cache/log để xem các mục này."))
                    .font(theme.font(size: 10)).foregroundStyle(theme.secondaryText).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(l.text("Chọn chỉ mục ít rủi ro")) { cleaner.selectLowerRisk() }
                    .controlSize(.small).disabled(cleaner.lowerRiskVisibleIDs.isEmpty || cleaner.isTrashing)
            }
            if !cleaner.usageCheckComplete {
                Label(l.text("Kiểm tra file đang mở chưa hoàn tất hoặc bị giới hạn quyền. Không có mục nào được gắn nhãn ít rủi ro."), systemImage: "exclamationmark.triangle")
                    .font(theme.font(size: 11)).foregroundStyle(theme.warning).fixedSize(horizontal: false, vertical: true)
            }
            if cleaner.visibleFiles.isEmpty {
                emptyState(icon: "checkmark.circle", title: cleaner.files.isEmpty ? l.text("Chưa có file phù hợp tiêu chí") : l.text("Không có kết quả phù hợp"), text: l.text("Bạn có thể đổi thư mục, bật quét cache hoặc thay đổi bộ lọc."))
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Button { cleaner.toggleVisible() } label: { Image(systemName: !cleaner.selectableVisibleIDs.isEmpty && cleaner.selectableVisibleIDs.isSubset(of: cleaner.selected) ? "checkmark.square.fill" : "square").foregroundStyle(theme.accent) }.buttonStyle(.plain).help(l.text("Chọn / bỏ chọn các file đang hiển thị")).disabled(cleaner.isTrashing || cleaner.selectableVisibleIDs.isEmpty)
                        Text(l.text("TÊN FILE")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(l.text("ĐÁNH GIÁ")).frame(width: 120, alignment: .leading)
                        Text(l.text("SỬA LẦN CUỐI")).frame(width: 85, alignment: .leading)
                        Text(l.text("DUNG LƯỢNG ↓")).frame(width: 90, alignment: .trailing)
                        Color.clear.frame(width: 30)
                    }.font(theme.font(size: 9, weight: .semibold)).tracking(0.5).foregroundStyle(theme.secondaryText).padding(.horizontal, 18).padding(.vertical, 15)
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(cleaner.visibleFiles) { file in
                                FileRow(file: file)
                                Divider().padding(.leading, 50)
                            }
                        }
                    }.frame(height: 285)
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(l.text("Đã chọn %@ file · %@", l.number(cleaner.selected.count), l.bytes(cleaner.selectedSize))).font(theme.font(size: 12, weight: .medium))
                            Text(l.text("Khôi phục từ Thùng rác trong Finder khi cần.")).font(theme.font(size: 10)).foregroundStyle(theme.secondaryText)
                        }
                        Spacer()
                        if cleaner.isTrashing { ProgressView().controlSize(.small) }
                        Button { cleaner.confirmTrash = true } label: { Label(cleaner.isTrashing ? l.text("Đang chuyển…") : l.text("Chuyển vào Thùng rác"), systemImage: "trash") }
                            .buttonStyle(PrimaryButton())
                            .disabled(cleaner.selected.isEmpty || cleaner.isTrashing)
                    }.padding(18)
                }.background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.border, lineWidth: 1))
            }
        }
        .sheet(isPresented: $cleaner.confirmTrash) { trashConfirmation }
    }
    private var trashConfirmation: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(l.text("Chuyển %@ file vào Thùng rác?", l.number(cleaner.selected.count)), systemImage: "trash").font(theme.font(size: 18, weight: .semibold))
            Text(l.text("Tổng dung lượng file: %@. Xem lại danh sách trước khi tiếp tục. Cache có thể được ứng dụng tạo lại.", l.bytes(cleaner.selectedSize)))
                .font(theme.font(size: 12)).foregroundStyle(theme.secondaryText)
            if cleaner.selectedReviewCount > 0 {
                Label(l.text("Có %@ file cần bạn tự xem lại; app chưa xác minh có thể bỏ dữ liệu này.", l.number(cleaner.selectedReviewCount)), systemImage: "exclamationmark.triangle")
                    .font(theme.font(size: 12)).foregroundStyle(theme.warning)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    ForEach(cleaner.selectedFiles) { file in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack { Text(file.name).lineLimit(1); Spacer(); Text(l.bytes(file.size)).foregroundStyle(theme.secondaryText) }
                            Text(file.url.path).font(theme.font(size: 10)).foregroundStyle(theme.secondaryText).textSelection(.enabled)
                            HStack(alignment: .top) {
                                RiskBadge(risk: file.assessment.risk)
                                Text(l.render(file.assessment.reason)).font(theme.font(size: 10)).foregroundStyle(theme.secondaryText)
                            }
                        }.font(theme.font(size: 12))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 220).padding(12).background(theme.background, in: RoundedRectangle(cornerRadius: 10))
            Text(l.text("App kiểm tra lại trước khi chuyển. File thay đổi, đang mở hoặc có mức rủi ro tăng sẽ được bỏ qua. Đây là kiểm tra tại thời điểm đó, không phải bảo đảm tuyệt đối."))
                .font(theme.font(size: 11)).foregroundStyle(theme.secondaryText)
            HStack {
                Spacer()
                Button(l.text("Hủy"), role: .cancel) { cleaner.confirmTrash = false }.keyboardShortcut(.cancelAction)
                Button(l.text("Chuyển vào Thùng rác")) { cleaner.confirmTrash = false; Task { await cleaner.trashSelected() } }.buttonStyle(PrimaryButton())
            }
        }.padding(26).frame(width: 570).background(theme.surface).foregroundStyle(theme.text)
    }
    private func filterButton(_ title: String, category: CleanupCategory?) -> some View {
        Button { cleaner.filter = category } label: {
            Text(title).font(theme.font(size: 11, weight: .medium)).foregroundStyle(cleaner.filter == category ? theme.accent : theme.secondaryText)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(cleaner.filter == category ? theme.selection : theme.surface, in: Capsule())
        }.buttonStyle(.plain)
    }
    private func emptyState(icon: String, title: String, text: String) -> some View {
        Panel {
            VStack(spacing: 17) {
                Image(systemName: icon).font(theme.font(size: 34, weight: .light)).foregroundStyle(theme.accent).frame(width: 84, height: 84).background(theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                Text(title).font(theme.font(size: 20, weight: .medium, design: .rounded))
                Text(text).font(theme.font(size: 12)).foregroundStyle(theme.secondaryText).multilineTextAlignment(.center).lineSpacing(6)
            }.frame(maxWidth: .infinity).padding(.vertical, 39)
        }
    }
}

struct FileRow: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let file: CleanupCandidate
    @EnvironmentObject var cleaner: CleanerModel
    var body: some View {
        HStack(spacing: 12) {
            Button { cleaner.toggle(file.id) } label: {
                Image(systemName: cleaner.selected.contains(file.id) ? "checkmark.square.fill" : "square").foregroundStyle(theme.accent)
            }.buttonStyle(.plain).accessibilityLabel(l.text("Chọn %@", file.name)).disabled(cleaner.isTrashing || !file.assessment.canSelect).help(l.render(file.assessment.reason))
            Image(nsImage: NSWorkspace.shared.icon(for: UTType(filenameExtension: file.url.pathExtension) ?? .data)).resizable().frame(width: 27, height: 27)
            VStack(alignment: .leading, spacing: 5) {
                Text(file.name).font(theme.font(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                Text(file.url.deletingLastPathComponent().path).font(theme.font(size: 10)).foregroundStyle(theme.secondaryText).lineLimit(1).truncationMode(.middle)
                Text(l.render(file.assessment.reason)).font(theme.font(size: 10)).foregroundStyle(file.assessment.risk.tint(in: theme)).lineLimit(2).help(l.render(file.assessment.reason))
            }.frame(maxWidth: .infinity, alignment: .leading).help(file.url.path)
            RiskBadge(risk: file.assessment.risk).frame(width: 120, alignment: .leading).help(l.render(file.assessment.reason))
            Text(file.modified, format: .dateTime.day().month().year().locale(l.locale)).font(theme.font(size: 10)).foregroundStyle(theme.secondaryText).frame(width: 85, alignment: .leading)
            Text(l.bytes(file.size)).font(theme.font(size: 12, weight: .medium)).monospacedDigit().frame(width: 90, alignment: .trailing)
            Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: { Image(systemName: "folder").foregroundStyle(theme.secondaryText) }
                .buttonStyle(.plain).help(l.text("Hiện trong Finder")).frame(width: 30)
        }.padding(.horizontal, 18).padding(.vertical, 14)
        .background(cleaner.selected.contains(file.id) ? theme.selection : Color.clear)
        .contextMenu {
            Button(l.text("Hiện trong Finder")) { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
        }
    }
}

private extension CleanupRisk {
    func tint(in theme: AppTheme) -> Color {
        switch self {
        case .lowerRisk: return theme.success
        case .review: return theme.warning
        case .avoid: return theme.danger
        }
    }
    var icon: String {
        switch self {
        case .lowerRisk: return "checkmark.shield"
        case .review: return "eye"
        case .avoid: return "hand.raised"
        }
    }
}

private struct RiskBadge: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let risk: CleanupRisk
    var body: some View {
        Label(l.text(risk.title), systemImage: risk.icon)
            .font(theme.font(size: 10, weight: .semibold)).foregroundStyle(risk.tint(in: theme))
            .padding(.horizontal, 7).padding(.vertical, 6)
            .background(risk.tint(in: theme).opacity(0.08), in: Capsule()).lineLimit(1).minimumScaleFactor(0.8)
    }
}
