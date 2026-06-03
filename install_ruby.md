# install_ruby.sh

Script tự động cài đặt và cấu hình môi trường **Ruby** phiên bản mới nhất trên hệ điều hành macOS sử dụng trình quản lý gói Homebrew.

## Chức năng
- **Kiểm tra trạng thái hiện tại:** Kiểm tra xem Ruby đã được cài đặt chưa. Nếu có sẵn, script sẽ hỏi người dùng có muốn nâng cấp lên phiên bản mới hay không.
- **Tự động cài đặt Homebrew:** Nếu máy chưa có Homebrew, script sẽ tự động tải và cài đặt, đồng thời cấu hình biến môi trường phù hợp với kiến trúc máy (Apple Silicon `/opt/homebrew` hoặc Intel `/usr/local`).
- **Cập nhật và Cài đặt Ruby:** Chạy `brew update` và cài đặt gói `ruby` bản mới nhất từ Homebrew.
- **Cấu hình đường dẫn (PATH):**
  - Tự động phát hiện Shell đang sử dụng để xác định tệp cấu hình phù hợp (`~/.zshrc` hoặc `~/.bash_profile`).
  - Thêm đường dẫn cài đặt Ruby của Homebrew vào đầu biến `PATH` để hệ thống ưu tiên sử dụng bản Homebrew thay cho phiên bản Ruby cũ đi kèm mặc định của hệ điều hành macOS.
  - Cấu hình các biến cờ biên dịch `LDFLAGS` và `CPPFLAGS` để hỗ trợ cài đặt các thư viện gem cần biên dịch mã nguồn C.
- **Kiểm tra xác thực:** Kiểm tra đường dẫn chạy lệnh và phiên bản Ruby sau khi cài đặt.
- **Cài đặt thư viện bổ trợ:** Tự động cài đặt công cụ quản lý dự án **Bundler** (`gem install bundler`).

## Cách sử dụng

1. **Cấp quyền thực thi và chạy script:**
   ```bash
   chmod +x install_ruby.sh
   ./install_ruby.sh
   ```

2. **Cung cấp phản hồi tương tác (nếu có):**
   Nếu hệ thống đã có sẵn Ruby, nhập `yes` để thực hiện nâng cấp hoặc `no` để hủy bỏ.

3. **Áp dụng các thay đổi đường dẫn:**
   Sau khi script thông báo hoàn thành thành công, bạn chạy lệnh sau để cập nhật cấu hình cho Terminal hiện tại:
   ```bash
   source ~/.zshrc      # Nếu bạn dùng Zsh
   # hoặc
   source ~/.bash_profile  # Nếu bạn dùng Bash
   ```
   Hoặc bạn chỉ cần khởi động lại Terminal.

## Cấu hình và Yêu cầu hệ thống
- **Hệ điều hành:** macOS.
- **Yêu cầu:** Máy cần có kết nối Internet để tải các gói từ Homebrew và Rubygems.
- **Quyền hạn:** Cần có quyền ghi vào các tệp cấu hình cá nhân trong thư mục người dùng (`$HOME`).
