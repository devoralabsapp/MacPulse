# MacPulse

[English](README.md) · [Giấy phép MIT](LICENSE) · [Hướng dẫn đóng góp](CONTRIBUTING.md)

**Trạng thái:** dự án mới, đang phát triển. Build Universal và 11 bài kiểm thử lõi đã đạt; giao diện và toàn bộ luồng chuyển vào Thùng rác vẫn cần kiểm tra thủ công. Xem [kết quả xác minh](VERIFICATION.md).

App macOS native bằng SwiftUI, giao diện tiếng Việt, theo dõi tài nguyên trực tiếp và giúp xem lại những file có thể dọn. Yêu cầu macOS 14 trở lên. Không có dịch vụ mạng, tài khoản hoặc thư viện bên thứ ba.

## Mở app

Sau khi build, mở `dist/MacPulse.app`. Có thể kéo app vào Applications nếu muốn cài đặt. Đóng cửa sổ vẫn theo dõi bằng biểu tượng trên thanh menu; chọn **Thoát MacPulse** để dừng hoàn toàn.

## Tính năng

- CPU: tỷ lệ toàn hệ thống, user/system/idle và biểu đồ 60 mẫu gần nhất.
- RAM: bộ nhớ đang dùng, wired, compressed, cache, swap và áp lực bộ nhớ nếu macOS cung cấp.
- Storage: tổng dung lượng, đang dùng và còn trống trên volume chứa thư mục cá nhân.
- Pin: phần trăm, điện lượng còn lại bằng mAh, dung lượng sạc đầy/thiết kế, số chu kỳ, điện áp, dòng điện và thời gian ước tính.
- Mạng: tốc độ tải lên/xuống trên giao diện mạng vật lý (không cộng lặp giao diện VPN/bridge).
- Dọn dẹp: thư mục tùy chọn, file từ 100 MB, file chưa chỉnh sửa từ 180 ngày; có thể quét thêm cache/log người dùng từ 30 ngày.
- Tìm theo tên/đường dẫn, lọc loại, hiện trong Finder, chọn nhiều file và xem danh sách xác nhận trước khi chuyển vào Thùng rác.
- Cài đặt chu kỳ lấy mẫu 1/2/5 giây và hiển thị trên thanh menu.

## Cách dọn file

1. Mở **Dọn dẹp** → **Chọn thư mục…** hoặc dùng Downloads mặc định.
2. Bật quét thêm cache/log nếu muốn, rồi **Bắt đầu quét**. Quét chỉ đọc metadata, không tự chọn file.
3. Xem kết quả và dùng biểu tượng thư mục để kiểm tra trong Finder. Ngày chỉnh sửa cũ chỉ là gợi ý, không chứng minh file đã hết sử dụng.
4. Chọn file → **Chuyển vào Thùng rác** → kiểm tra danh sách rồi xác nhận.
5. File vẫn chiếm dung lượng cho đến khi tự dọn Thùng rác trong Finder. Có thể dùng **Put Back / Đặt lại** trong Finder để khôi phục trước đó.

MacPulse không xóa vĩnh viễn, không gỡ ứng dụng, không dọn RAM cưỡng bức và không can thiệp hệ thống. Quét bỏ qua file ẩn, symlink, alias, app/package, thư mục phát triển `node_modules`, vùng hệ thống và Library ngoài Caches/Logs. Không tải file iCloud chỉ có trên cloud. Trước khi chuyển file, app kiểm tra lại đường dẫn, inode, dung lượng và ngày sửa để bỏ qua file đã thay đổi. Cache có thể được ứng dụng tạo lại; không nên chọn file nếu chưa biết công dụng.

Nếu macOS từ chối truy cập, chọn lại thư mục bằng hộp thoại hoặc cấp quyền **Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Tệp và thư mục**. App không yêu cầu quyền quản trị. Quét giới hạn 100.000 mục/lần; thư mục quá lớn nên chia thành các thư mục con. Kết quả không được lưu giữa các lần mở app.

## Build & kiểm thử

Cần Xcode hoặc Command Line Tools có Swift 6 trở lên.

```sh
git clone https://github.com/devoralabsapp/MacPulse.git
cd MacPulse
bash scripts/test.sh
bash scripts/build-app.sh
open dist/MacPulse.app
```

Build Universal cho cả Apple Silicon và Intel:

```sh
bash scripts/build-app.sh --universal
```

Đầu ra gồm `dist/MacPulse.app` và `dist/MacPulse.zip`. App được ký ad hoc cho sử dụng cục bộ; chưa có chữ ký Developer ID/notarization để phân phối công khai. Nếu phân phối, hãy đặt bundle ID của bạn, ký bằng Developer ID và notarize theo quy trình Apple. Mở `Package.swift` trong Xcode để phát triển; bản `.app` từ script có Info.plist, biểu tượng và định danh ổn định cho quyền thư mục.

Tests dùng thư mục tạm riêng: phân loại tuổi/kích thước, cache mới, symlink, thư mục được bảo vệ, giới hạn quét, hủy, chống trùng, phát hiện file thay đổi/thay thế và kiểm tra parser pin không nhầm `%` thành `mAh`. Không test bằng cách xóa file của người dùng.

## Nguồn số liệu & giới hạn

- CPU: `host_statistics`; mẫu đầu cần chờ một chu kỳ để tính delta.
- RAM: `host_statistics64` và `vm.swapusage`; dùng active + inactive − purgeable − file-backed + wired + compressed. Có thể chênh lệch Giám sát hoạt động do thời điểm lấy mẫu và cách phân loại của macOS. Áp lực bộ nhớ chỉ hiển thị khi sysctl được hệ thống hỗ trợ.
- Storage: `volumeTotalCapacity` / `volumeAvailableCapacity` của thư mục cá nhân. APFS và dung lượng có thể thu hồi khiến số khác màn hình Storage trong Cài đặt. Dung lượng file trong bộ quét là logical size, không phải cam kết dung lượng thực thu hồi (APFS clone, sparse file và nén có thể khác).
- Pin: IOPS cung cấp `%` và trạng thái nguồn; IOKit `AppleSmartBattery` cung cấp `AppleRawCurrentCapacity`/`AppleRawMaxCapacity` hoặc giá trị mAh kiểu cũ khi có. Những khóa registry này phụ thuộc phần cứng/macOS. Thiếu dữ liệu sẽ hiển thị `—`, không lấy phần trăm đổi thành mAh.
- Sức khỏe pin là full-charge capacity / design capacity, không phải chẩn đoán bảo hành của Apple. Dòng điện dương khi sạc, âm khi xả, có thể bằng 0 khi giữ mức sạc.

Tham khảo API chính thức: [IOPowerSources](https://developer.apple.com/documentation/iokit/iopowersources_h), [IOPMPowerSource](https://developer.apple.com/documentation/kernel/iopmpowersource), [NSWorkspace.recycle](https://developer.apple.com/documentation/appkit/nsworkspace/recycle(_:completionhandler:)).

## Mã nguồn mở

MacPulse phát hành theo [MIT License](LICENSE). Xem [hướng dẫn đóng góp](CONTRIBUTING.md), [lộ trình](ROADMAP.md) và [chính sách báo lỗi bảo mật](SECURITY.md). Giao diện hiện tại dùng tiếng Việt; bản tiếng Anh nằm trong lộ trình.

Dự án được phát triển ban đầu với sự hỗ trợ của OpenAI Codex. MacPulse là dự án độc lập; không tuyên bố được OpenAI tài trợ hoặc đã được chấp nhận vào chương trình nào.
