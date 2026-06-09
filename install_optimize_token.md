# install_optimize_token.sh

Script tự động cài đặt và cấu hình công cụ **RTK (Rust Token Killer)** - một bộ CLI proxy trung gian viết bằng ngôn ngữ Rust, giúp tối ưu hóa chi phí API và cải thiện độ chính xác của các AI Agent bằng cách nén dữ liệu đầu vào.

## Chức năng
- **Giới thiệu công cụ:** Cung cấp thông tin tổng quan về chức năng của RTK.
- **Tải và cài đặt tự động:** Thực hiện tải tệp chạy chính thức thông qua script cài đặt từ website `rtk.ai` (`curl -fsSL https://rtk.ai/install.sh | sh`).
- **Tự động cài đặt công cụ tối ưu hóa ngữ cảnh (context-optimization):** Kiểm tra xem lệnh `npx` có sẵn trên hệ thống không. Nếu chưa có, script tự động cài đặt Node.js thông qua Homebrew để bổ sung `npx`, sau đó tự động đăng ký/cài đặt thêm skill `context-optimization` cho các AI Agent thông qua lệnh `npx skills add ...`.
- **Phát hiện và cấu hình Shell:** Tự động nhận diện Shell của người dùng (`zsh`, `bash`, hoặc các Shell khác) để xác định tệp cấu hình tương ứng (`~/.zshrc`, `~/.bashrc` hoặc `~/.profile`).
- **Thiết lập Alias tối ưu cho AI Agent:** Tự động bổ sung các Alias vào tệp cấu hình Shell để AI Agent sử dụng RTK làm lớp trung gian khi gọi lệnh:
  - `git` $\rightarrow$ `rtk git`
  - `npm` $\rightarrow$ `rtk npm`
  - `cargo` $\rightarrow$ `rtk cargo`
  - `pytest` $\rightarrow$ `rtk pytest`
  - Giúp tự động cắt giảm 60% - 90% số lượng token đầu vào bằng cách lọc bỏ log rác, khoảng trắng dư thừa và chỉ giữ lại thông tin lỗi cốt lõi.

## Cách sử dụng

1. **Cấp quyền thực thi và chạy script:**
   ```bash
   chmod +x install_optimize_token.sh
   ./install_optimize_token.sh
   ```

2. **Xác nhận cài đặt:**
   Nhập `y` hoặc `Y` khi được hỏi để xác nhận bắt đầu quá trình tải xuống và cài đặt.

3. **Áp dụng thay đổi:**
   Sau khi hoàn tất, hãy chạy lệnh sau để áp dụng các cấu hình alias ngay lập tức cho cửa sổ Terminal hiện tại:
   ```bash
   source ~/.zshrc      # Nếu bạn dùng Zsh
   # hoặc
   source ~/.bashrc     # Nếu bạn dùng Bash
   ```
   Hoặc bạn có thể tắt đi và mở lại cửa sổ Terminal mới.

## Cấu hình và Yêu cầu hệ thống
- **Yêu cầu kết nối:** Cần kết nối Internet ổn định để tải công cụ từ máy chủ RTK.
- **Quyền hạn:** Cần có quyền ghi vào các tệp cấu hình Shell của người dùng tại thư mục `$HOME`.
