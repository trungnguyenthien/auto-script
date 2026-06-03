# b64_dir.sh

Script mã hóa tất cả các tệp tin trong một thư mục được chỉ định thành định dạng Base64.

## Chức năng
- Duyệt qua toàn bộ các tệp tin trong thư mục đầu vào (không duyệt đệ quy vào thư mục con).
- Bỏ qua các thư mục, liên kết mềm (symlink), các tệp tin không có quyền đọc hoặc các tệp tin đã được mã hóa trước đó (có đuôi `.b64`).
- Chuyển đổi nội dung các tệp hợp lệ sang Base64 và lưu thành tệp mới có phần mở rộng `.b64` trong cùng thư mục.
- Tương thích tốt với hệ điều hành macOS (đặc biệt là macOS ARM / Apple Silicon).

## Cách sử dụng

1. **Cấp quyền thực thi cho script (nếu chưa có):**
   ```bash
   chmod +x b64_dir.sh
   ```

2. **Chạy script với tham số là đường dẫn thư mục chứa các tệp cần mã hóa:**
   ```bash
   ./b64_dir.sh <đường_dẫn_thư_mục>
   ```

   *Ví dụ:*
   ```bash
   ./b64_dir.sh ./my_documents
   ```

## Cấu hình và Yêu cầu hệ thống
- **Công cụ yêu cầu:** Phải cài đặt sẵn lệnh `base64` trên hệ thống (đã có sẵn mặc định trên macOS và hầu hết các bản phân phối Linux).
- **Quyền hạn:** Cần có quyền đọc (`read`) thư mục mục tiêu và các tệp tin bên trong, đồng thời có quyền ghi (`write`) để tạo các tệp `.b64` mới.
