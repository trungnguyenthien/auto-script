# db_security_scanner.rb

Script Ruby hỗ trợ quét và phát hiện các thông tin nhạy cảm (thông tin cá nhân, API keys, tokens, mật khẩu, v.v.) bên trong cơ sở dữ liệu SQLite3.

## Chức năng
- **Quét cấu trúc (Schema):** Kiểm tra tên các cột của tất cả các bảng trong cơ sở dữ liệu để tìm các từ khóa nhạy cảm.
- **Quét dữ liệu (Data):** Duyệt qua dữ liệu từng dòng trong các bảng và sử dụng biểu thức chính quy (Regex) cùng danh sách từ khóa để nhận diện thông tin nhạy cảm.
- **Mẫu Regex tích hợp:**
  - Email tiêu chuẩn.
  - Số điện thoại toàn cầu (Universal Phone Regex) tuân theo chuẩn quốc tế E.164.
- **Bộ từ khóa nhạy cảm phong phú:**
  - Các loại mã xác thực: `token`, `access_token`, `refresh_token`, `jwt`, `cookie`, `password`, `secret`, `key`, `apiKey`, `client_secret`.
  - Thông tin cá nhân (PII): `email`, `phone`, `username`, `fullname`, `address`, `passport`, `license`, `ssn`, `gps`.
  - Tài chính & Ví điện tử: `credit`, `debit`, `cvv`, `bank`, `account`, `vnpay`, `momo`, `stripe`, `paypal`, `zalopay`.
  - Dịch vụ đám mây: `aws`, `s3`, `firebase`, `google_api`, `database_url`.

## Cách sử dụng

1. **Cài đặt thư viện yêu cầu:**
   Script yêu cầu thư viện `sqlite3` dành cho Ruby. Thực hiện cài đặt bằng lệnh:
   ```bash
   gem install sqlite3
   ```

2. **Chạy quét tệp cơ sở dữ liệu:**
   ```bash
   ruby db_security_scanner.rb <đường_dẫn_file_db>
   ```

   *Ví dụ:*
   ```bash
   ruby db_security_scanner.rb ./app_data.db
   ```

3. **Xem trợ giúp:**
   ```bash
   ruby db_security_scanner.rb -h
   # hoặc
   ruby db_security_scanner.rb --help
   ```

## Cấu hình và An toàn dữ liệu
- **Chế độ Read-only:** Script tự động mở cơ sở dữ liệu ở chế độ chỉ đọc (`db.readonly = true`), đảm bảo tuyệt đối không làm thay đổi hoặc hư hại dữ liệu gốc trong quá trình quét.
- **Bảo mật:** Quá trình quét được thực hiện hoàn toàn cục bộ (offline) trên máy tính của bạn, không gửi bất kỳ dữ liệu nào ra bên ngoài.
