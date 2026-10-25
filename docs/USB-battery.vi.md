# Đọc báo cáo pin iPhone/iPad qua USB

[English](USB-battery.md) · [Hướng dẫn iOS](iOS.vi.md)

MacPulse trên Mac dùng công cụ nguồn mở [libimobiledevice](https://github.com/libimobiledevice/libimobiledevice/blob/master/tools/idevicediagnostics.c) để truy vấn dịch vụ chẩn đoán của iPhone/iPad kết nối USB. Đây là luồng đọc từ máy tính đã được thiết bị tin cậy. MacPulse không tích hợp hay phụ thuộc vào 3uTools.

## Đọc trên Mac

1. Cài công cụ USB tùy chọn bằng [Homebrew](https://formulae.brew.sh/formula/libimobiledevice):

   ```sh
   brew install libimobiledevice
   ```

2. Cắm iPhone/iPad bằng cáp USB, mở khóa và chọn **Tin cậy máy tính này** nếu được hỏi.
3. Trong MacPulse, mở **Pin & nguồn điện → Pin iPhone / iPad qua USB**.
4. Bấm **Tìm thiết bị**, chọn đúng máy rồi **Đọc pin qua USB**. Nếu có nhiều thiết bị, menu phân biệt bằng 6 ký tự cuối mã USB; mã đầy đủ chỉ giữ trong bộ nhớ và truyền cho công cụ để chọn đúng máy.
5. Đặt **Nhãn thiết bị** dễ nhận biết rồi **Xuất báo cáo pin** thành JSON. Tránh ghi thông tin cá nhân trong nhãn nếu chia sẻ file.

App tìm `idevice_id` và `idevicediagnostics` tại `/opt/homebrew/bin` hoặc `/usr/local/bin`, không chạy qua shell và không tự cài phần mềm. Chỉ liệt kê thiết bị USB (`idevice_id -l`), mỗi lệnh truy vấn đều chọn mã thiết bị cụ thể. Mỗi lệnh có thời gian chờ 10 giây, giới hạn đầu ra 2 MB; ba truy vấn có thể mất khoảng 30 giây. Không có lệnh khởi động lại, tắt máy, sửa thiết lập hoặc đọc nội dung file trên iPhone.

libimobiledevice được cài riêng, có giấy phép LGPL-2.1-or-later. MacPulse vẫn có giấy phép MIT; không đóng gói công cụ/thư viện này trong app và không liên kết chúng vào iOS. Hiện cần cài thủ công; chưa tự tìm đường dẫn Homebrew khác hai vị trí trên.

## Xem trên iPhone/iPad

Chuyển JSON qua AirDrop, iCloud Drive hoặc vị trí khác trong Files. Mở **Tổng quan → Thông tin pin từ máy Mac → Nhập báo cáo pin**, chọn file. Báo cáo hợp lệ gần nhất được lưu cục bộ qua các lần mở app; **Bỏ báo cáo đã nhập** sẽ bỏ bản lưu đó. Nhập lỗi giữ nguyên báo cáo cũ.

App hiển thị nhãn, thời điểm đọc, nguồn và tên trường từng chỉ số. Đây là **bản ghi tại thời điểm đọc**, nằm riêng với mức pin/trạng thái sạc trực tiếp. App không tự xác nhận báo cáo thuộc iPhone/iPad đang xem. Chưa có đồng bộ trực tiếp, máy chủ mạng hay tunnel USB vào app iOS.

## Trường được hỗ trợ

Thứ tự truy vấn: `ioregentry AppleSmartBattery`, `ioregentry AppleARMPMUCharger`, `diagnostics GasGauge`. Trường thiếu có thể lấy từ phản hồi tiếp theo của cùng thiết bị đã chọn. Khả năng cung cấp phụ thuộc model và phiên bản iOS; đọc được dịch vụ không bảo đảm đủ mọi trường.

| Chỉ số | Trường được nhận |
| --- | --- |
| Dung lượng thiết kế, mAh | `BatteryData.DesignCapacity` hoặc `DesignCapacity` |
| Dung lượng sạc đầy, mAh | `AppleRawMaxCapacity`, `BatteryData.NominalChargeCapacity`, `NominalChargeCapacity`; `FullChargeCapacity` chỉ từ GasGauge và phải lớn hơn 100 |
| Điện lượng còn lại, mAh | `AppleRawCurrentCapacity`, nhận cả giá trị 0 hợp lệ |
| Số chu kỳ | `CycleCount`, nhận cả 0 |

Bỏ qua `MaxCapacity` và `CurrentCapacity` vì có thể là phần trăm. `FullChargeCapacity = 100` cũng không được gắn nhãn mAh; kho mã upstream đã ghi nhận trường hợp trả về thang chuẩn hóa này. Không suy đổi mAh từ phần trăm; không lấy `Qmax` làm dung lượng thiết kế.

Số liệu firmware không phải phép đo dung lượng vật lý độc lập. Nếu sạc đầy lớn hơn thiết kế, hoặc còn lại lớn hơn sạc đầy, app giữ nguyên các số đọc, cảnh báo và ẩn tỷ lệ sức khỏe pin. Tỷ lệ sạc đầy/thiết kế khi nhất quán chỉ là ước tính, không thay cho Tình trạng pin của Apple. Trường không có hiển thị **—**. Cần đối chiếu trên thiết bị thật trước khi nhận thêm định dạng firmware khác.

## Định dạng và riêng tư

JSON phiên bản 1 gồm `schemaVersion`, `deviceLabel`, `capturedAt` theo ISO-8601 và các trường tùy chọn `design`, `maximum`, `current`, `cycles`. Mỗi chỉ số có `value` nguyên, `query` và `field` thuộc danh sách được hỗ trợ. [File ví dụ dùng số liệu giả](examples/battery-report.example.json).

Không xuất UDID, số sê-ri pin/máy, đầu ra chẩn đoán thô, hồ sơ ghép đôi hay tên máy từ lockdown. Báo cáo nhập là tài liệu chưa xác thực, không phải chứng nhận phần cứng có chữ ký. Trường JSON ngoài danh sách bị bỏ khi lưu lại model. App kiểm tra phiên bản, đơn vị/tên trường, khoảng giá trị, nhãn, thời điểm và giới hạn 64 KB; đọc file thường có phối hợp File Coordinator và giới hạn số byte. Từ chối thời điểm tương lai quá 5 phút; kiểm tra đồng hồ hai máy nếu gặp lỗi.

MacPulse không tự tải báo cáo lên mạng. Vị trí chuyển file như iCloud Drive có hành vi đồng bộ riêng.

## Phạm vi kiểm tra

Kiểm thử tự động dùng plist/JSON giả, phản hồi USB giả lập, kiểm tra giới hạn đầu ra/thời gian chờ và nhập file trên Simulator. Còn cần xác minh số đọc firmware, hộp Tin cậy, rút cáp lúc đọc và chọn nhiều thiết bị trên iPhone/iPad thật. Thiếu trường vẫn hiện **—**.
