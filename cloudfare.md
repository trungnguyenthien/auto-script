# `cloudfare.sh` — Cloudflare Tunnel Manager

## Công dụng

Script quản lý **Cloudflare Tunnel** để public các app chạy local ra internet qua domain riêng — **không cần mở port router / NAT**.

- Ánh xạ `domain ↔ localhost:port` qua file `cloudfare.yml`.
- Tự động tạo tunnel + route DNS + restart service.
- Cài tunnel thành system service — tự khởi động lại sau khi reboot.

## Quick Start

Domain phải dùng Cloudflare DNS. KHÔNG chạy script với `sudo`.

**1. Chạy script**

```bash
bash cloudfare.sh
```

Lần đầu script tự cài `cloudflared`, tạo file `cloudfare.yml` mẫu rồi thoát.

**2. Sửa file `cloudfare.yml`** — mỗi route 1 dòng `<domain> <port>`:

```yaml
# tunnel_name: my-tunnel          # (optional; uncomment để override)
myapp.ngthientrung.com 12345
api.ngthientrung.com 3000
```

**3. Chạy lại script**

```bash
bash cloudfare.sh
```

Khi được hỏi login Cloudflare, chọn:
- `1)` nếu máy này có trình duyệt → tự mở `dash.cloudflare.com/argotunnel`.
- `2)` muốn login trên máy khác → URL được copy vào clipboard, mở trên thiết bị khác + Authorize.

Script tự sync + restart service. Truy cập `https://myapp.ngthientrung.com` từ bất kỳ đâu.

## Menu

```
1) Sync now         # apply cloudfare.yml changes to Cloudflare
2) Show status      # show tunnel + routes + TCP check targets
3) Exit
```

## Thay đổi routes

Sửa `cloudfare.yml` rồi chạy lại `bash cloudfare.sh` — không cần nhập gì trên terminal.

## Quyền

macOS: script tự hỏi `sudo` khi cài launchd service. Windows 11: chạy Git Bash với quyền Administrator. Linux / WSL: chỉ in hướng dẫn chạy thủ công.