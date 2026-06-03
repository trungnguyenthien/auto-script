# install_ios_simulators.sh

Script dòng lệnh tương tác hỗ trợ tạo và quản lý hàng loạt các thiết bị giả lập iOS (iOS Simulator) trên hệ điều hành macOS kiến trúc ARM (Apple Silicon).

## Chức năng
- **Quét môi trường thông minh:**
  - Tự động kiểm tra kiến trúc chip Apple Silicon (ARM64) và sự tồn tại của công cụ `xcodebuild`.
  - Tự động quét và liệt kê danh sách các iOS Runtime (phiên bản hệ điều hành) đã được tải về trên máy.
  - Tự động quét và liệt kê danh sách các mẫu máy phần cứng (iPhone/iPad) được Xcode hỗ trợ.
- **Tạo giả lập hàng loạt (Batch Creation):**
  - Cho phép chọn nhiều phiên bản iOS cùng lúc.
  - Cho phép chọn các mẫu thiết bị cụ thể, hoặc chọn nhanh theo bộ lọc: `all` (tất cả thiết bị), `iphone` (chỉ các dòng iPhone), `ipad` (chỉ các dòng iPad).
  - Tự động đặt tên giả lập theo quy chuẩn đồng bộ: `[iOS <Phiên_bản>] <Tên_thiết_bị>` (Ví dụ: `[iOS 18.2] iPhone 16 Pro`).
  - Kiểm tra và tự động bỏ qua nếu giả lập đã tồn tại trước đó để tránh trùng lặp.
  - Tích hợp cơ chế kiểm soát thời gian chờ (Timeout 30s) cho mỗi lần tạo nhằm tránh hiện tượng treo lệnh của `simctl`.
- **Xem thông tin hệ thống:** Xem nhanh danh sách simulator hiện có, các iOS Runtime và các mẫu thiết bị được hỗ trợ.
- **Xóa giả lập hàng loạt (Batch Deletion):**
  - Xóa tất cả các giả lập được tạo theo định dạng `[iOS`.
  - Xóa toàn bộ giả lập của một phiên bản iOS cụ thể (ví dụ: xóa hết giả lập iOS 17.5).
  - Lựa chọn xóa thủ công từng giả lập thông qua danh sách đánh số.

## Cách sử dụng

1. **Cấp quyền thực thi và khởi chạy script:**
   ```bash
   chmod +x install_ios_simulators.sh
   ./install_ios_simulators.sh
   ```

2. **Sử dụng menu chức năng:**
   Sau khi khởi chạy, script sẽ hiển thị giao diện menu số:
   - **Tùy chọn 1:** Bắt đầu quy trình chọn thiết bị và iOS phiên bản để tạo hàng loạt.
   - **Tùy chọn 2:** Xem danh sách giả lập hiện có trên máy.
   - **Tùy chọn 3:** Xem danh sách phiên bản hệ điều hành iOS đã cài đặt.
   - **Tùy chọn 4:** Xem danh sách mã định danh của các thiết bị iPhone/iPad được hỗ trợ.
   - **Tùy chọn 5:** Truy cập menu con phục vụ xóa giả lập hàng loạt.
   - **Tùy chọn 6:** Thoát chương trình.

## Cấu hình và Yêu cầu hệ thống
- **Hệ điều hành:** Yêu cầu macOS chạy chip ARM (M1/M2/M3/M4...).
- **Công cụ yêu cầu:** Bắt buộc cài đặt **Xcode** đầy đủ (cung cấp lệnh `xcrun simctl`).
- **Yêu cầu hệ điều hành giả lập:** Script yêu cầu máy của bạn đã tải sẵn ít nhất một iOS Runtime. Nếu danh sách Runtimes trống, hãy mở Xcode, truy cập **Xcode > Settings > Platforms** và tải về phiên bản iOS mong muốn trước khi chạy script.
