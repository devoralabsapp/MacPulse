# MacPulse trên iPhone và iPad

[English](iOS.md) · [Giới thiệu dự án](../README.vi.md)

Bản native SwiftUI yêu cầu **iOS/iPadOS 17 trở lên**. iPhone dùng tab ở dưới; iPad dùng thanh bên khi đủ rộng, hỗ trợ cửa sổ đa nhiệm. Dùng chung 4 bảng màu, chế độ sáng/tối/hệ thống, tiếng Việt/Anh với bản Mac. App đọc số liệu của thiết bị đang chạy, không điều khiển hay theo dõi từ xa một máy Mac.

## Cài lên iPhone/iPad của bạn

1. Mở `iOS/MacPulse.xcodeproj` bằng Xcode có Swift 6 trở lên.
2. Chọn scheme **MacPulse-iOS**, target **MacPulseMobile**.
3. Trong **Signing & Capabilities**, chọn Team của Apple ID/Developer của bạn. Đổi Bundle Identifier `com.macpulse.mobile` nếu Team cần tên riêng. Kho mã không chứa tài khoản hay thông tin ký.
4. Kết nối iPhone/iPad, bật Developer Mode khi được yêu cầu, chọn thiết bị rồi **Run (⌘R)**.

Có thể chọn Simulator iPhone/iPad để chạy thử. Bản build thiết bị chưa ký không thể cài bằng cách chép file `.app` hoặc `.zip` sang iPhone. Phát hành qua TestFlight/App Store cần tài khoản, ký và quy trình duyệt của bạn; chưa có bản phát hành iOS công khai. [Hướng dẫn thiết bị của Apple](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device).

## Phạm vi theo dõi trên iOS

- **CPU:** chỉ tiến trình MacPulse, chuẩn hóa theo tổng số lõi. Không phải CPU toàn thiết bị.
- **RAM:** bộ nhớ vật lý MacPulse đang chiếm dụng, RAM vật lý thiết bị và lượng app còn có thể cấp phát. Giới hạn này thay đổi theo iOS, không phải tổng RAM trống.
- **Storage:** tổng/còn trống của volume chứa app; APFS và dữ liệu có thể thu hồi có thể làm số khác Cài đặt.
- **Pin:** phần trăm, trạng thái sạc, nguồn điện thấp và trạng thái nhiệt của hệ điều hành. Không suy ra mAh, sức khỏe, dung lượng thiết kế hoặc chu kỳ từ phần trăm.
- **Mạng:** upload/download, biểu đồ, từng giao diện và tổng quan sát khi app hoạt động. Có thể gồm app khác và mạng nội bộ; không phải speed test hay số liệu tính cước.
- **Dọn dẹp:** chỉ thư mục bạn cấp quyền qua Files, xem trước, tự chọn, khôi phục và xác nhận xóa vĩnh viễn. Không dọn cache hay dữ liệu riêng của ứng dụng khác.

Lấy mẫu dừng khi app không hoạt động; khi trở lại sẽ lấy mốc CPU/mạng mới. Bộ đếm iOS công khai có thể quay vòng: app để khoảng trống và lấy mốc lại khi số đọc giảm, không đoán tốc độ. Không gửi yêu cầu đo mạng, không đọc nội dung gói tin/IP/SSID, không có analytics hoặc tài khoản.

**Simulator có thể phản ánh phần cứng máy Mac**, pin có thể không có số liệu và hiện **—**. Kiểm thử Simulator không thay thế kiểm tra pin trên thiết bị thật. Xem [API pin công khai](https://developer.apple.com/documentation/uikit/uidevice/batterylevel) và [giới hạn cấp phát của app](https://developer.apple.com/documentation/os/os_proc_available_memory).

## Dọn file và khôi phục

Chọn thư mục trong Files. App tìm file từ 100 MB hoặc chưa sửa từ 180 ngày, không chọn sẵn mục nào. Không thể kiểm tra file đang mở bởi app khác trên iOS; nhãn chỉ là cần xem lại hoặc không khuyến nghị, không khẳng định file đã hết sử dụng. Bỏ qua/chặn các định dạng nhạy cảm, cơ sở dữ liệu, bản sao lưu, tải dở, symlink, package, file khóa hoặc có nhiều liên kết.

**Chuyển vào khu khôi phục** di chuyển vào thư mục **`MacPulse Recovery` ngay trong thư mục/nhà cung cấp bạn chọn**. Đây không phải Thùng rác hệ thống hoặc mục Đã xóa gần đây của Files. File vẫn chiếm dung lượng. Chọn lại cùng thư mục để xem và khôi phục sau khi khởi động lại; nếu quyền bookmark hết hiệu lực, chọn lại trong Files.

- **Khôi phục:** đưa về vị trí gốc, không ghi đè file trùng tên. Nếu thư mục cha đã mất/thay đổi, tự lấy file bằng Files.
- **Xóa vĩnh viễn:** xác nhận riêng, MacPulse không thể hoàn tác. Dung lượng thực thu hồi còn phụ thuộc APFS và thời gian lưu của nhà cung cấp.
- **iCloud/nhà cung cấp khác:** di chuyển/khôi phục/xóa có thể đồng bộ sang thiết bị khác. App nhắc trước xác nhận. Quét metadata không tải file iCloud chưa có trên máy; xem trước có thể khiến nhà cung cấp tải nội dung.
- Thư mục trùng tên nhưng không có dấu định dạng MacPulse sẽ không bị nhận làm khu khôi phục. Nếu record hoặc file bị thay đổi, app từ chối thao tác không an toàn; file `payload` vẫn có thể lấy thủ công trong Files.

App cân bằng thời gian truy cập security scope, phối hợp thao tác qua File Coordinator và kiểm tra lại đường dẫn, metadata trước khi di chuyển. Đây không phải bảo đảm tuyệt đối file đã hết sử dụng hay nhà cung cấp không thay đổi đồng thời. Hãy thử bằng file dùng thử. [Cách iOS cấp quyền thư mục](https://developer.apple.com/documentation/uikit/providing-access-to-directories).

## Build và kiểm thử

```sh
bash scripts/test.sh
bash scripts/build-ios.sh
bash scripts/build-ios.sh --device
bash scripts/test-ios.sh
```

`--device` tạo bản arm64 **chưa ký**, dùng để kiểm tra build; cài lên máy thật bằng Xcode và Team của bạn. Muốn kiểm thử iPad cụ thể, dùng `DESTINATION='platform=iOS Simulator,id=UUID-CUA-SIMULATOR' bash scripts/test-ios.sh`. Tìm UUID với `xcrun simctl list devices available`. Test chỉ tạo và dọn fixture tạm, không quét thư mục cá nhân.

Project Xcode có sẵn trong kho. Script tạo lại project chỉ cần khi phát triển: `gem install xcodeproj`, rồi `ruby scripts/generate-ios-project.rb`. App không phụ thuộc thư viện bên thứ ba khi chạy. Privacy manifest khai báo lý do dùng API preferences, thời gian, dung lượng và metadata file; cần rà soát khi đổi API hoặc phát hành.
