# install_ruby.sh

Script tự động cài đặt và cấu hình môi trường quản lý phiên bản **Ruby** trên hệ điều hành macOS sử dụng công cụ **rbenv**.

## Chức năng
- **Tự động cài đặt Homebrew:** Nếu máy chưa có Homebrew, script sẽ tự động tải, cài đặt và cấu hình biến môi trường phù hợp với kiến trúc máy (Apple Silicon `/opt/homebrew` hoặc Intel `/usr/local`).
- **Cài đặt rbenv & ruby-build:** Tự động cài đặt hoặc nâng cấp `rbenv` và plugin `ruby-build` qua Homebrew.
- **Cấu hình rbenv cho Shell:**
  - Tự động phát hiện Shell đang sử dụng (`~/.zshrc` hoặc `~/.bash_profile`).
  - Thêm script khởi tạo `rbenv init` vào tệp cấu hình shell của bạn để tự động nạp các shims của rbenv.
- **Tự động tìm kiếm phiên bản Ruby Stable mới nhất:**
  - Script tự động truy vấn danh sách các phiên bản cài đặt từ rbenv để tìm ra phiên bản ổn định (stable) mới nhất.
  - Cho phép người dùng tùy chọn: Cài đặt bản ổn định mới nhất, nhập phiên bản tùy chọn (Custom), hoặc Hủy.
- **Kiểm tra và Tránh cài đặt trùng lặp:** Nếu phiên bản Ruby được chọn đã được cài đặt trong rbenv trước đó, script sẽ bỏ qua bước biên dịch để tiết kiệm thời gian.
- **Cài đặt thư viện bổ trợ:** Tự động cài đặt công cụ quản lý thư viện **Bundler** (`gem install bundler`) cho phiên bản Ruby vừa thiết lập.

## Cách sử dụng

1. **Cấp quyền thực thi và chạy script:**
   ```bash
   chmod +x install_ruby.sh
   ./install_ruby.sh
   ```

2. **Cung cấp phản hồi tương tác:**
   Khi được hỏi, hãy chọn phương án cài đặt mong muốn:
   *   Nhấn `Enter` hoặc nhập `yes` để cài phiên bản Stable mới nhất.
   *   Nhập `custom` hoặc `c` để cài đặt một phiên bản cụ thể khác (ví dụ: `3.2.2`).
   *   Nhập `no` hoặc `n` để hủy bỏ cài đặt.

3. **Áp dụng thay đổi cho phiên chạy hiện tại:**
   Sau khi script chạy xong, hãy tải lại cấu hình shell để rbenv bắt đầu hoạt động ngay lập tức:
   ```bash
   source ~/.zshrc      # Nếu bạn dùng Zsh
   # hoặc
   source ~/.bash_profile  # Nếu bạn dùng Bash
   ```
   *Hoặc đơn giản là khởi động lại ứng dụng Terminal của bạn.*

## Cách kiểm tra hoạt động

Sau khi chạy lệnh `source` hoặc mở lại Terminal mới, bạn có thể kiểm tra xem hệ thống đã sử dụng đúng Ruby của rbenv chưa:

```bash
which ruby
# Nên trả về: /Users/<tên_user>/.rbenv/shims/ruby

ruby --version
# Nên hiển thị đúng phiên bản bạn vừa chọn cài đặt
```

## Cấu hình và Yêu cầu hệ thống
- **Hệ điều hành:** macOS.
- **Yêu cầu:** Máy cần có kết nối Internet để tải/biên dịch mã nguồn Ruby từ các server chính thức của Ruby và Rubygems.
- **Quyền hạn:** Ghi tệp cấu hình cá nhân trong thư mục người dùng (`$HOME`). Không cần quyền `sudo` để cài đặt phiên bản Ruby hoặc gem vì chúng được lưu trữ trực tiếp trong thư mục cá nhân của bạn (`~/.rbenv/`).
