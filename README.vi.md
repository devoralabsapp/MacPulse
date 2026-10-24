# MacPulse

[English](README.md) · [Giấy phép MIT](LICENSE) · [Hướng dẫn đóng góp](CONTRIBUTING.md)

**Trạng thái:** dự án mới, đang phát triển. Có kiểm thử tự động và build Universal; giao diện và toàn bộ luồng chuyển vào Thùng rác vẫn cần kiểm tra thủ công. Xem [kết quả xác minh](VERIFICATION.md).

App macOS native bằng SwiftUI, giao diện tiếng Việt và tiếng Anh, theo dõi tài nguyên trực tiếp và giúp xem lại những file có thể dọn. Yêu cầu macOS 14 trở lên. Không có dịch vụ mạng, tài khoản hoặc thư viện bên thứ ba.

## Mở app

Sau khi build, mở `dist/MacPulse.app`. Có thể kéo app vào Applications nếu muốn cài đặt. Đóng cửa sổ vẫn theo dõi bằng biểu tượng trên thanh menu; chọn **Thoát MacPulse** để dừng hoàn toàn.

Đổi ngôn ngữ bằng biểu tượng bánh răng hoặc **⌘, → Ngôn ngữ / Language → English / Tiếng Việt / Theo hệ thống**. Lựa chọn được lưu và áp dụng ngay cho nội dung app, thanh menu riêng và thông báo, kể cả kết quả quét đang có. Hộp thoại và menu tiêu chuẩn do macOS quản lý vẫn theo thiết lập ngôn ngữ của macOS.

## Tính năng

- CPU: tỷ lệ toàn hệ thống, user/system/idle và biểu đồ 60 mẫu gần nhất.
- RAM: bộ nhớ đang dùng, wired, compressed, cache, swap và áp lực bộ nhớ nếu macOS cung cấp.
- Storage: tổng dung lượng, đang dùng và còn trống trên volume chứa thư mục cá nhân.
- Pin: phần trăm, điện lượng còn lại bằng mAh, dung lượng điện sạc đầy và dung lượng thiết kế do firmware báo được ghi riêng; số chu kỳ, điện áp, dòng điện và thời gian ước tính.
- Mạng: tốc độ tải lên/xuống trên giao diện mạng vật lý (không cộng lặp giao diện VPN/bridge).
- Dọn dẹp: thư mục tùy chọn, file từ 100 MB, file chưa chỉnh sửa từ 180 ngày; có thể quét thêm cache/log người dùng từ 30 ngày.
- Tìm theo tên/đường dẫn, lọc loại, hiện trong Finder, chọn nhiều file và xem danh sách xác nhận trước khi chuyển vào Thùng rác.
- Đánh giá từng file: **ít rủi ro / cần xem lại / không khuyến nghị**, ghi rõ lý do; có bộ lọc và nút chọn chỉ các mục ít rủi ro đang hiển thị.
- Cài đặt chu kỳ lấy mẫu 1/2/5 giây và hiển thị trên thanh menu.

## Cách dọn file

1. Mở **Dọn dẹp** → **Chọn thư mục…** hoặc dùng Downloads mặc định.
2. Bật quét thêm cache/log nếu muốn, rồi **Bắt đầu quét**. Quét chỉ đọc metadata, không tự chọn file.
3. Xem mức đánh giá, lý do từng file và dùng biểu tượng thư mục để kiểm tra trong Finder. Ngày chỉnh sửa cũ chỉ là gợi ý, không chứng minh file đã hết sử dụng. Nút **Chọn chỉ mục ít rủi ro** thay thế lựa chọn hiện tại bằng các mục ít rủi ro đang hiển thị.
4. Chọn file → **Chuyển vào Thùng rác** → kiểm tra danh sách rồi xác nhận.
5. File vẫn chiếm dung lượng cho đến khi tự dọn Thùng rác trong Finder. Có thể dùng **Put Back / Đặt lại** trong Finder để khôi phục trước đó.

MacPulse không xóa vĩnh viễn, không gỡ ứng dụng, không dọn RAM cưỡng bức và không can thiệp hệ thống. Quét bỏ qua file ẩn, symlink, alias, app/package, thư mục phát triển `node_modules`, vùng hệ thống và Library ngoài Caches/Logs. Không tải file iCloud chỉ có trên cloud. Trước khi chuyển file, app kiểm tra lại đường dẫn, inode, dung lượng và ngày sửa để bỏ qua file đã thay đổi. Cache có thể được ứng dụng tạo lại; không nên chọn file nếu chưa biết công dụng.

**Ít rủi ro** chỉ áp dụng cho một số file `.cache`, `.tmp`, `.temp` trong thư mục cache chuẩn và nhật ký cũ nhận diện được trong Logs. Các ngày sửa/tạo/truy cập được cung cấp phải cũ ít nhất 30 ngày, kiểm tra file đang mở phải hoàn tất, và chưa quan sát thấy file hoặc ứng dụng sở hữu đang hoạt động. Đây là gợi ý, không phải bảo đảm an toàn tuyệt đối; cache có thể cần tải lại, còn xóa log sẽ mất lịch sử chẩn đoán.

**Cần xem lại** dành cho file cá nhân, định dạng chưa nhận diện, hoạt động gần đây hoặc kiểm tra chưa đầy đủ. **Không khuyến nghị** và chặn chọn đối với file đang mở, cache/log của app đang chạy, dữ liệu đồng bộ nhận diện được, cơ sở dữ liệu, khóa bảo mật, bản sao lưu, file tải dở, file bị khóa hoặc nhiều liên kết.

App dùng `lsof` cho các tiến trình của người dùng hiện tại và đọc danh sách ứng dụng đang chạy; không dùng sudo, không đọc nội dung file và không gửi danh sách lên mạng. Khi lệnh cảnh báo, lỗi, không có kết quả hoặc hết thời gian, app không gắn nhãn ít rủi ro. Trước khi chuyển vào Thùng rác, app lấy lại ảnh chụp trạng thái sử dụng và đánh giá lại; nếu file bị chặn hoặc mục ít rủi ro không còn đạt tiêu chí, app bỏ qua. Kiểm tra chỉ có giá trị tại thời điểm thực hiện và không phát hiện được mọi tình huống hay dịch vụ đồng bộ.

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
- RAM: `host_statistics64` và `vm.swapusage`; dùng active + inactive − purgeable − file-backed + wired + compressed. RAM và swap dùng đơn vị nhị phân (1024) với nhãn GB theo macOS: máy 32 GiB sẽ hiển thị **32 GB**, không còn 34,36 GB. Ổ đĩa và dung lượng file vẫn dùng hệ thập phân. Có thể chênh lệch Giám sát hoạt động do thời điểm lấy mẫu và cách phân loại.
- Storage: `volumeTotalCapacity` / `volumeAvailableCapacity` của thư mục cá nhân. APFS và dung lượng có thể thu hồi khiến số khác màn hình Storage trong Cài đặt. Dung lượng file trong bộ quét là logical size, không phải cam kết dung lượng thực thu hồi (APFS clone, sparse file và nén có thể khác).
- Pin: IOPS cung cấp `%` và trạng thái nguồn; IOKit `AppleSmartBattery` cung cấp điện lượng mAh, bao gồm các trường trong `BatteryData` trên phiên bản macOS mới. Thiếu dữ liệu sẽ hiển thị `—`, không lấy phần trăm đổi thành mAh.
- Dung lượng thiết kế lấy từ `DesignCapacity`, không thay bằng dung lượng sạc đầy hoặc `Qmax`. Nếu firmware báo sạc đầy lớn hơn mốc thiết kế, app giữ nguyên hai số đọc nhưng cảnh báo cần xác minh và không tính sức khỏe pin từ cặp số đó; không hiện trên 100%, không tự sửa mốc thiết kế hoặc ép kết quả về 100%. Tình trạng do macOS báo được hiển thị riêng. Số đọc firmware không phải phép đo dung lượng vật lý độc lập. Dòng điện dương khi sạc, âm khi xả, có thể bằng 0 khi giữ mức sạc.

Tham khảo API chính thức: [IOPowerSources](https://developer.apple.com/documentation/iokit/iopowersources_h), [IOPMPowerSource](https://developer.apple.com/documentation/kernel/iopmpowersource), [NSWorkspace.recycle](https://developer.apple.com/documentation/appkit/nsworkspace/recycle(_:completionhandler:)).

## Mã nguồn mở

MacPulse phát hành theo [MIT License](LICENSE). Xem [hướng dẫn đóng góp](CONTRIBUTING.md), [lộ trình](ROADMAP.md) và [chính sách báo lỗi bảo mật](SECURITY.md). Bản dịch có trong `Sources/MacPulseCore/Resources/{en,vi}.lproj/Localizable.strings`.

Dự án được phát triển ban đầu với sự hỗ trợ của OpenAI Codex. MacPulse là dự án độc lập; không tuyên bố được OpenAI tài trợ hoặc đã được chấp nhận vào chương trình nào.
