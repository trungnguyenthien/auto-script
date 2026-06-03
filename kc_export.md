# kc_export.sh

Script hỗ trợ quét, liệt kê và xuất các chứng chỉ số (certificates) từ phân vùng Keychain của người dùng (Login keychain) và hệ thống (System keychain) trên hệ điều hành macOS.

## Chức năng
- **Quét và Liệt kê:**
  - Tự động quét các chứng chỉ phục vụ cho việc ký code (codesigning) và các chứng chỉ thông thường từ hai keychain:
    - Login keychain: `~/Library/Keychains/login.keychain-db`
    - System keychain: `/Library/Keychains/System.keychain`
  - Hiển thị danh sách chứng chỉ dưới dạng bảng thông tin trực quan gồm: Chỉ số (Idx), Loại keychain (login/system), Mã băm SHA1 và Tên Common Name (CN).
- **Xuất chứng chỉ dạng PKCS#12 (`.p12`):**
  - Cho phép người dùng chọn chứng chỉ cần xuất thông qua số chỉ mục.
  - Cho phép thiết lập mật khẩu bảo vệ (passphrase) cho tệp khóa `.p12` xuất ra (hoặc bỏ trống).
  - Tự động tạo thư mục `./exported_certs` để lưu trữ tệp tin đầu ra.
- **Cơ chế xử lý thông minh khi xuất lỗi:**
  - Nếu lệnh xuất thông thường bị từ chối hoặc thất bại: Script sẽ gợi ý người dùng thử lại bằng quyền nâng cao (`sudo` và mở khóa keychain bằng lệnh `security unlock-keychain`).
  - Nếu việc xuất khóa riêng tư (private key) vẫn thất bại (do khóa riêng tư không tồn tại trên máy, bị đánh dấu không cho phép xuất, hoặc nằm trên chip bảo mật Secure Enclave / thẻ thông minh): Script sẽ tự động chuyển sang cơ chế dự phòng (fallback) là xuất chỉ riêng phần chứng chỉ công khai (public certificate) lưu dưới dạng tệp tin PEM/CER (`.cer`).

## Cách sử dụng

1. **Cấp quyền thực thi và chạy script:**
   ```bash
   chmod +x kc_export.sh
   ./kc_export.sh
   ```

2. **Quy trình xuất:**
   - Script hiển thị bảng danh sách chứng chỉ tìm thấy.
   - Nhập chỉ số tương ứng với chứng chỉ muốn xuất và nhấn **Enter** (hoặc nhấn **Enter** trực tiếp để thoát).
   - Nhập mật khẩu bảo vệ tệp khóa đầu ra (ký tự mật khẩu sẽ được ẩn để bảo mật). Nhấn **Enter** để bỏ qua nếu không muốn đặt mật khẩu.
   - Tệp tin chứng chỉ sau khi xuất thành công sẽ được lưu tại thư mục `./exported_certs` nằm cùng cấp với script.

## Cấu hình và Yêu cầu hệ thống
- **Hệ điều hành:** macOS.
- **Công cụ yêu cầu:** Sử dụng lệnh hệ thống `security` có sẵn trên macOS.
- **Quyền hạn:** Việc xuất chứng chỉ thông thường không cần quyền root. Tuy nhiên, nếu cần truy cập và mở khóa System Keychain hoặc xuất các chứng chỉ có độ bảo mật cao, script sẽ yêu cầu bạn nhập mật khẩu tài khoản macOS của mình để thực thi lệnh qua `sudo`.
- **Thư mục đầu ra:** Tự động tạo thư mục `exported_certs` cùng cấp để lưu chứng chỉ đã xuất.
