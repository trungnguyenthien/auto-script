# install_flutter_env.sh

Script tự động cài đặt và thiết lập toàn bộ môi trường phát triển ứng dụng **Flutter** trên hệ điều hành macOS (đặc biệt tối ưu hóa cho chip Apple Silicon - ARM64).

## Chức năng
Script thực hiện tuần tự 7 bước cài đặt và cấu hình:

1. **Homebrew:** Trình quản lý gói cho macOS. Tự động thêm Homebrew vào PATH.
2. **Xcode Command Line Tools:** Bộ công cụ biên dịch bắt buộc. Nếu phát hiện ứng dụng Xcode (`/Applications/Xcode.app`), script sẽ tự động cấu hình đường dẫn lập trình và chấp nhận điều khoản sử dụng.
3. **Java 17 (OpenJDK):** Cần thiết cho việc biên dịch ứng dụng Android. Cấu hình sẵn biến môi trường `JAVA_HOME` và cập nhật `PATH`.
4. **Ruby:** Cài đặt phiên bản mới nhất qua Homebrew để tránh xung đột với Ruby hệ thống của macOS, thêm vào PATH.
5. **CocoaPods:** Phiên bản 1.16.2+ phục vụ việc quản lý thư viện iOS/macOS, kèm theo các công cụ hỗ trợ debug iOS (`libimobiledevice`, `ideviceinstaller`, `ios-deploy`).
6. **Android SDK:**
   - Tự động tải và cài đặt Android SDK Command Line Tools (phiên bản `11076708`).
   - Cài đặt SDK packages cần thiết: `platform-tools`, các phiên bản hệ điều hành Android API 34, 35, 36 và `build-tools;35.0.0`.
   - Cấu hình các biến môi trường `ANDROID_HOME`, `ANDROID_SDK_ROOT` và thêm các thư mục liên quan vào PATH.
7. **Flutter SDK:**
   - Tải và giải nén Flutter SDK phiên bản `3.38.2` dành riêng cho Apple Silicon (ARM64).
   - Thêm Flutter vào PATH, cấu hình tắt thu thập dữ liệu ẩn danh (`--no-analytics`).
   - Chấp nhận tất cả bản quyền Android (`flutter doctor --android-licenses`) và tải trước tài nguyên cần thiết cho cả Android và iOS (`precache`).

Cuối cùng, script sẽ tự động nạp lại cấu hình shell (`source ~/.zshrc`) và chạy lệnh kiểm tra tổng thể `flutter doctor -v`.

## Cách sử dụng

1. **Cấp quyền thực thi và chạy script:**
   ```bash
   chmod +x install_flutter_env.sh
   ./install_flutter_env.sh
   ```

2. **Xác nhận cài đặt:**
   Một danh sách các công cụ sắp cài đặt sẽ hiện ra. Nhấn **Enter** để tiếp tục cài đặt hoặc nhấn **Ctrl+C** để hủy bỏ.

3. **Nhập mật khẩu máy (Sudo Password):**
   Script sẽ yêu cầu quyền quản trị ở đầu chương trình để thực hiện một số thao tác cài đặt hệ thống. Script có cơ chế tự duy trì quyền sudo chạy ngầm để bạn không cần nhập lại mật khẩu nhiều lần.

## Tính năng cài đặt thông minh (Idempotent)
- Mọi bước cài đặt thành công được lưu vết tại tệp nhật ký `~/.flutter_env_install.log`.
- Nếu quá trình cài đặt bị gián đoạn (do lỗi mạng hoặc sự cố khác), bạn chỉ cần chạy lại script. Script sẽ tự động bỏ qua những bước đã hoàn thành trước đó để tiết kiệm thời gian.
- **Reset cài đặt:** Để cài đặt lại từ đầu toàn bộ các bước, thực hiện xóa tệp nhật ký:
  ```bash
  rm ~/.flutter_env_install.log
  ```

## Cấu hình và Yêu cầu hệ thống
- **Hệ điều hành:** macOS chạy trên chip **Apple Silicon (M1/M2/M3/M4...)**. Script không hỗ trợ kiến trúc Intel (x86_64).
- **Shell mặc định:** Script mặc định ghi cấu hình biến môi trường vào tệp `~/.zshrc`.
- **Yêu cầu iOS đầy đủ:** Để build được ứng dụng lên Simulator hoặc thiết bị thật iOS, bạn vẫn cần tải ứng dụng **Xcode** đầy đủ từ App Store sau khi chạy xong script.
