# install_headroom.sh

Script tự động cài đặt công cụ **Headroom proxy** (bộ nén ngữ cảnh context compression proxy dành cho AI agents giúp tiết kiệm từ 60–95% lượng token đầu vào) và tự động thiết lập cấu hình tích hợp hoàn hảo với **Claude Code**.

## Chức năng
- **Kiểm tra Prerequisites:** Tìm kiếm phiên bản Python phù hợp (yêu cầu $\ge 3.10$). Nếu hệ thống thiếu Python, script hỗ trợ tự động cài đặt qua Homebrew (trên macOS) hoặc các trình quản lý gói như `apt`, `dnf`, `yum`, `pacman` (trên Linux).
- **Thu thập cấu hình linh hoạt:** Hỏi người dùng các thông tin cần thiết:
  - `CUSTOM_ANTHROPIC_BASE_URL`: API Endpoint thực tế cần chuyển tiếp (Ví dụ: OpenRouter, Vertex AI, Ollama, v.v.).
  - `ANTHROPIC_AUTH_TOKEN`: API key hoặc mã xác thực tương ứng.
  - Model mặc định để sử dụng (ví dụ: `aws/claude-sonnet-4-6-medium`).
  - Port chạy proxy (mặc định: `8787`).
- **Lựa chọn phương thức cài đặt:**
  1. **pip:** Cài đặt trực tiếp vào môi trường Python hiện tại.
  2. **pipx:** Cài đặt độc lập (isolated) giúp tránh xung đột thư viện (khuyến nghị).
  3. **docker:** Chạy thông qua Docker container (không cần cài đặt các thư viện Python).
- **Dọn dẹp môi trường cũ:** Giải phóng port chạy proxy bị chiếm dụng và làm sạch bộ nhớ đệm cache tại `~/.cache/headroom`.
- **Quản lý dịch vụ tự động (Daemon):**
  - Tạo cấu hình môi trường tại `~/.config/headroom/.env`.
  - Tạo script khởi động nhanh tại `~/.local/bin/headroom-start`.
  - **Trên macOS:** Tạo và kích hoạt launchd service tại `~/Library/LaunchAgents/ai.headroom.proxy.plist` giúp tự động khởi chạy cùng hệ điều hành.
  - **Trên Linux:** Tạo và kích hoạt systemd user service tại `~/.config/systemd/user/headroom-proxy.service`.
- **Tự động cấu hình Claude Code:** Tạo tệp cấu hình `.claude/settings.json` trỏ endpoint `ANTHROPIC_BASE_URL` về Headroom proxy cục bộ, cấu hình API key, cấu hình model và thiết lập tối ưu hóa lưu lượng.

## Cách sử dụng

1. **Chạy script:**
   ```bash
   bash install_headroom.sh
   ```

2. **Cung cấp các thông tin cấu hình** hiển thị trực quan trên giao diện terminal theo nhu cầu sử dụng của bạn.

## Các tệp tin được tạo ra
- `.claude/settings.json`: Cấu hình của dự án hiện tại trỏ về proxy.
- `~/.config/headroom/.env`: Biến môi trường chạy proxy.
- `~/.local/bin/headroom-start`: Script thủ công khởi động proxy.
- `~/Library/LaunchAgents/ai.headroom.proxy.plist` (macOS) hoặc `~/.config/systemd/user/headroom-proxy.service` (Linux): Quản lý chạy ngầm.

## Quản lý dịch vụ thủ công

### Trên macOS:
- **Khởi động proxy:** `launchctl load ~/Library/LaunchAgents/ai.headroom.proxy.plist`
- **Dừng proxy:** `launchctl unload ~/Library/LaunchAgents/ai.headroom.proxy.plist`
- **Xem nhật ký hoạt động:** `tail -f ~/.config/headroom/proxy.log`

### Trên Linux:
- **Khởi động proxy:** `systemctl --user start headroom-proxy`
- **Dừng proxy:** `systemctl --user stop headroom-proxy`
- **Xem nhật ký hoạt động:** `journalctl --user -u headroom-proxy -f`

### Chạy bằng Docker (nếu chọn chế độ 3):
- **Khởi động proxy:** `bash ~/.local/bin/headroom-start`
- **Dừng proxy:** `docker stop headroom-proxy && docker rm headroom-proxy`
- **Xem nhật ký hoạt động:** `docker logs -f headroom-proxy`
