# install_snyk_android.sh

Script tự động kiểm tra và cài đặt công cụ quét lỗ hổng bảo mật **Snyk CLI** trên hệ thống macOS, chuẩn bị môi trường để thực hiện quét bảo mật dự án (đặc biệt thích hợp cho các dự án Android).

## Chức năng
- **Kiểm tra môi trường:**
  - Kiểm tra trình quản lý gói Homebrew. Nếu thiếu, script sẽ hiển thị thông báo hướng dẫn cài đặt Homebrew.
  - Kiểm tra Node.js. Nếu thiếu, tự động tải và cài đặt thông qua Homebrew.
  - Kiểm tra và đảm bảo trình quản lý gói `npm` hoạt động bình thường.
- **Cài đặt Snyk CLI:**
  - Kiểm tra xem lệnh `snyk` đã tồn tại chưa.
  - Nếu chưa có, script tiến hành cài đặt Snyk CLI toàn cục bằng lệnh: `npm install -g snyk`.
- **Thử nghiệm chạy quét:**
  - Sau khi cài đặt thành công, script sẽ tự động chạy thử nghiệm lệnh `snyk test` ngay tại thư mục hiện hành của dự án để quét lỗ hổng bảo mật của các thư viện phụ thuộc (dependencies).

## Cách sử dụng

1. **Cấp quyền thực thi và chạy script:**
   ```bash
   chmod +x install_snyk_android.sh
   ./install_snyk_android.sh
   ```

2. **Xác thực với tài khoản Snyk:**
   Nếu là lần đầu tiên sử dụng Snyk trên máy tính của bạn, lệnh `snyk test` ở cuối script có thể yêu cầu bạn đăng nhập. Hãy làm theo chỉ dẫn trên màn hình (thông thường trình duyệt sẽ mở để bạn đăng nhập qua Google/GitHub).

## Cấu hình và Yêu cầu hệ thống
- **Hệ điều hành:** macOS (đã cài đặt sẵn Homebrew).
- **Quyền hạn cài đặt:** Tùy thuộc vào cấu hình `npm` trên máy, lệnh cài đặt global (`npm install -g`) có thể yêu cầu quyền quản trị. Nếu gặp lỗi phân quyền ghi, bạn có thể chỉnh sửa lệnh cài đặt hoặc chạy script với quyền `sudo`.
- **Hoạt động quét:** Snyk hỗ trợ quét bảo mật cho dự án Android bằng cách đọc các tệp cấu hình dependencies như `build.gradle` hoặc `build.gradle.kts`. Do đó, nên chạy script này trong thư mục gốc của dự án cần quét.
