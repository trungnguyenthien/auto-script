# convert_plist.rb

Script Ruby hỗ trợ kiểm tra và chuyển đổi tệp cấu hình thuộc tính của Apple (`.plist`) từ định dạng Nhị phân (Binary) sang định dạng XML (Plaintext) để dễ dàng đọc và chỉnh sửa.

## Chức năng
- Tự động nhận diện định dạng của tệp `.plist` đầu vào bằng lệnh `file`.
- Nếu phát hiện tệp đang ở định dạng **Apple binary property list**:
  - Sử dụng công cụ `plutil` chuyển đổi sang dạng XML1.
  - Lưu kết quả thành tệp mới có đuôi `.raw.plist` nằm cùng thư mục.
- Nếu tệp đã ở dạng **Plaintext/XML**:
  - Sao chép tệp gốc thành tệp mới có đuôi `.raw.plist` để giữ tính đồng bộ cho dự án.

## Cách sử dụng

1. **Chạy script với lệnh ruby và truyền đường dẫn tệp `.plist` làm đối số:**
   ```bash
   ruby convert_plist.rb <đường_dẫn_tệp_plist>
   ```

   *Ví dụ:*
   ```bash
   ruby convert_plist.rb ./Info.plist
   ```

2. **Kết quả đầu ra:**
   Sau khi chạy thành công, một tệp mới có tên dạng `[tên_tệp_gốc].raw.plist` sẽ được tạo ra tại cùng thư mục chứa tệp gốc.

## Cấu hình và Yêu cầu hệ thống
- **Môi trường:** Yêu cầu đã cài đặt **Ruby** trên máy.
- **Công cụ hệ thống:** Script sử dụng hai công cụ dòng lệnh là `file` và `plutil` (mặc định đã có sẵn trên macOS).
- **Quyền hạn:** Cần có quyền đọc tệp `.plist` nguồn và quyền ghi trong thư mục chứa tệp để tạo tệp `.raw.plist`.
