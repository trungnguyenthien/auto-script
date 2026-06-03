# ios_sim_manager.sh

Script dòng lệnh tương tác hỗ trợ quản lý vận hành (khởi động, xóa dữ liệu và tắt) các thiết bị giả lập iOS (iOS Simulator) sẵn có trên hệ điều hành macOS.

## Chức năng
- **Kiểm tra công cụ hệ thống:** Đảm bảo môi trường đã cài đặt công cụ phát triển `xcodebuild`.
- **Quét và hiển thị trạng thái thiết bị:** Tự động lọc danh sách các giả lập iPhone và iPad hiện có, hiển thị tên thiết bị kèm biểu tượng trạng thái trực quan:
  - 🔴 **Shutdown:** Thiết bị đang tắt.
  - 🟢 **Booted:** Thiết bị đang chạy ngầm hoặc đang hiển thị.
- **Các tác vụ quản lý tương tác:**
  1. **Khởi động Simulator (Boot & Open):** Khởi chạy thiết bị giả lập được lựa chọn và mở giao diện phần mềm Simulator trên màn hình máy Mac (`open -a Simulator`). Nếu thiết bị đã chạy trước đó, script sẽ chỉ mở cửa sổ giao diện lên.
  2. **Xóa sạch dữ liệu (Factory Reset - Wipe):** Xóa tất cả các ứng dụng cài thêm, dữ liệu người dùng và đưa thiết bị về trạng thái mặc định như lúc mới cài. Script tích hợp cơ chế:
     - Tự động tắt thiết bị trước khi xóa (bắt buộc đối với tiến trình `simctl`).
     - Yêu cầu người dùng xác nhận bằng cách gõ `yes` để tránh thao tác nhầm lẫn gây mất mát dữ liệu kiểm thử.
  3. **Tắt tất cả thiết bị (Shutdown ALL):** Tắt đồng loạt toàn bộ các giả lập đang hoạt động chạy ngầm trên máy Mac của bạn.
  4. **Thoát chương trình.**

## Cách sử dụng

1. **Cấp quyền thực thi và khởi chạy script:**
   ```bash
   chmod +x ios_sim_manager.sh
   ./ios_sim_manager.sh
   ```

2. **Thao tác trên Menu chính:**
   Nhập các số từ `1` đến `4` để chọn chức năng tương ứng:
   - **Tùy chọn 1:** Chọn thiết bị để bật và hiển thị lên màn hình.
   - **Tùy chọn 2:** Chọn thiết bị và xác nhận gõ `yes` để khôi phục cài đặt gốc.
   - **Tùy chọn 3:** Tắt toàn bộ simulator đang chạy ngầm để giải phóng tài nguyên CPU/RAM cho máy.
   - **Tùy chọn 4:** Thoát công cụ.

## Cấu hình và Yêu cầu hệ thống
- **Hệ điều hành:** macOS.
- **Công cụ yêu cầu:** Yêu cầu đã cài đặt **Xcode** (cung cấp bộ công cụ `simctl`).
- **Quyền hạn:** Không yêu cầu quyền root/sudo, chỉ chạy với quyền user thông thường.
