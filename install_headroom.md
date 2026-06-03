# install-headroom.sh

Script tự động cài đặt [Headroom](https://github.com/chopratejas/headroom) — context compression proxy cho Claude Code — và cấu hình toàn bộ `.claude/settings.json` chỉ với một lần chạy.

---

## Headroom là gì?

Headroom là một proxy đứng giữa Claude Code và LLM backend, tự động nén context trước khi gửi request. Kết quả là ít token hơn 60–95% mà output không thay đổi, giúp giảm chi phí và tăng tốc độ phản hồi đáng kể khi làm việc với các tác vụ có context lớn như code review, tool calls, hay RAG.

```
Claude Code
    │  ANTHROPIC_BASE_URL=http://localhost:8787
    ▼
┌─────────────────────────────────────────┐
│  Headroom Proxy  (localhost:8787)        │
│  • Nén tool outputs, logs, RAG          │
│  • CacheAligner cho KV cache hits       │
│  • CCR reversible compression           │
└─────────────────────────────────────────┘
    │  forward tới
    ▼
https://your-backend.com/api  (Ollama, OpenRouter, Vertex, v.v.)
```

---

## Yêu cầu

| Thành phần | Yêu cầu          | Ghi chú                        |
| ---------- | ---------------- | ------------------------------ |
| OS         | macOS hoặc Linux | Windows chưa hỗ trợ            |
| Python     | 3.10+            | Script tự động cài nếu chưa có |
| Docker     | Tuỳ chọn         | Chỉ cần nếu chọn chế độ Docker |

---

## Cách sử dụng

### Bước 1 — Tải script

```bash
curl -O https://raw.githubusercontent.com/your-repo/install-headroom.sh
# hoặc
wget https://raw.githubusercontent.com/your-repo/install-headroom.sh
```

### Bước 2 — Chạy script

> **Quan trọng:** chạy script từ thư mục project của bạn — file `.claude/settings.json` sẽ được tạo tại đây.

```bash
cd /path/to/your/project
bash install-headroom.sh
```

### Bước 3 — Trả lời các câu hỏi

Script hỏi lần lượt 5 thông tin:

```
CUSTOM_ANTHROPIC_BASE_URL : http://localhost:11434
ANTHROPIC_AUTH_TOKEN      : your-api-key-here
Model mặc định            : minimax-m3:cloud   (Enter để bỏ qua)
Port cho Headroom proxy   : 8787               (Enter để giữ mặc định)
Chọn chế độ cài [1/2/3]  : 1
```

Sau đó script tự chạy hoàn toàn không cần thêm thao tác nào.

---

## Các thông số đầu vào

### `CUSTOM_ANTHROPIC_BASE_URL` _(bắt buộc)_

URL của LLM backend thực sự mà bạn muốn dùng. Headroom sẽ forward request tới đây sau khi nén context.

| Backend         | Ví dụ URL                       |
| --------------- | ------------------------------- |
| Ollama local    | `http://localhost:11434`        |
| OpenRouter      | `https://openrouter.ai/api/v1`  |
| Vertex AI proxy | `https://vertex-key.com/api/v1` |
| LM Studio       | `http://localhost:1234/v1`      |

### `ANTHROPIC_AUTH_TOKEN` _(tuỳ chọn)_

API key hoặc token cho backend ở trên. Nếu bỏ qua, script dùng chuỗi `headroom` làm placeholder.

### `Model mặc định` _(tuỳ chọn)_

Tên model theo cú pháp của backend. Nếu để trống, không ghi vào `settings.json` — Claude Code sẽ dùng model mặc định của nó.

```
minimax-m3:cloud
aws/claude-sonnet-4-6-medium
glm-5.1:cloud
```

### Port _(mặc định: 8787)_

Port Headroom proxy lắng nghe trên máy local. Chỉ thay đổi nếu port này đã bị chiếm bởi service khác.

### Chế độ cài đặt

| Chế độ     | Mô tả                                             | Khi nào dùng            |
| ---------- | ------------------------------------------------- | ----------------------- |
| `1` pip    | Cài `headroom-ai` vào Python environment hiện tại | Nhanh, đơn giản         |
| `2` pipx   | Cài isolated, không ảnh hưởng Python global       | Khuyến nghị cho máy dev |
| `3` docker | Chạy headroom trong container                     | Không muốn cài Python   |

---

## Những gì script thực hiện

### 1. Kiểm tra & cài Python

Script tìm Python 3.10+ theo thứ tự: `python3` → `python` → `python3.13` → ... → `python3.10`.

Nếu không tìm thấy, script tự cài:

- **macOS** — dùng Homebrew (tự cài Homebrew nếu chưa có)
- **Linux** — dùng `apt` / `dnf` / `yum` / `pacman` tuỳ distro

Nếu chỉ có Python < 3.10, script vẫn tiếp tục với cảnh báo thay vì dừng lại.

### 2. Cài Headroom

Cài package `headroom-ai[all]` qua pip hoặc pipx tuỳ lựa chọn.

### 3. Dọn dẹp instance cũ

Mỗi lần chạy script, trước khi tạo service mới:

```bash
# Kill process đang giữ port
lsof -ti :8787 | xargs kill -9

# Kill theo tên process (phòng trường hợp đổi port)
pkill -9 -f "headroom proxy"

# Xoá cache cũ
rm -rf ~/.cache/headroom
```

Đảm bảo không bao giờ bị lỗi `address already in use` khi chạy lại script.

### 4. Tạo file cấu hình

**`~/.config/headroom/.env`** — lưu thông tin upstream:

```bash
ANTHROPIC_TARGET_API_URL=http://localhost:11434
ANTHROPIC_API_KEY=your-api-key
HEADROOM_PORT=8787
```

**`~/.local/bin/headroom-start`** — script khởi động thủ công:

```bash
bash ~/.local/bin/headroom-start
```

### 5. Đăng ký service tự động khởi động

- **macOS** — tạo `~/Library/LaunchAgents/ai.headroom.proxy.plist`, đăng ký với `launchctl`. Headroom tự chạy khi login.
- **Linux** — tạo `~/.config/systemd/user/headroom-proxy.service`, enable với `systemctl --user`. Headroom tự chạy khi login.

### 6. Tạo `.claude/settings.json`

Ghi vào thư mục hiện tại — Claude Code tự đọc khi chạy `claude` trong thư mục đó:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:8787",
    "ANTHROPIC_AUTH_TOKEN": "your-api-key",
    "ANTHROPIC_API_KEY": "your-api-key",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_INTERLEAVED_THINKING": "1"
  },
  "model": "minimax-m3:cloud"
}
```

`ANTHROPIC_BASE_URL` luôn trỏ vào Headroom proxy (`localhost:8787`), không phải backend trực tiếp.

### 7. Quick test

Khởi động Headroom một lần để xác nhận không có lỗi, sau đó dừng lại — service thực sự được quản lý bởi launchd/systemd.

---

## Các file được tạo ra

```
.claude/settings.json                          ← project hiện tại
~/.config/headroom/.env                        ← config upstream
~/.local/bin/headroom-start                    ← start script thủ công
~/Library/LaunchAgents/ai.headroom.proxy.plist ← macOS auto-start
~/.config/systemd/user/headroom-proxy.service  ← Linux auto-start
~/.config/headroom/proxy.log                   ← stdout log
~/.config/headroom/proxy-error.log             ← stderr log
```

---

## Quản lý service sau khi cài

### macOS

```bash
# Start
launchctl load ~/Library/LaunchAgents/ai.headroom.proxy.plist

# Stop
launchctl unload ~/Library/LaunchAgents/ai.headroom.proxy.plist

# Xem logs
tail -f ~/.config/headroom/proxy.log
```

### Linux

```bash
# Start
systemctl --user start headroom-proxy

# Stop
systemctl --user stop headroom-proxy

# Xem logs
journalctl --user -u headroom-proxy -f
```

### Docker (chế độ 3)

```bash
# Start
bash ~/.local/bin/headroom-start

# Stop
docker stop headroom-proxy && docker rm headroom-proxy

# Xem logs
docker logs -f headroom-proxy
```

---

## Kiểm tra hoạt động

```bash
# Health check
curl -s http://localhost:8787/health | python3 -m json.tool

# Xem thống kê token đã tiết kiệm
headroom stats

# Test request trực tiếp
curl -s http://localhost:8787/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "your-model",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "hi"}]
  }'
```

Nếu `health` trả về `"status": "healthy"` và request không bị 401, mọi thứ hoạt động đúng.

---

## Xử lý sự cố

### Lỗi 401 Invalid bearer token

Headroom đang forward đúng nhưng backend reject token. Kiểm tra:

```bash
# Xem headroom đang forward đến đâu và dùng token gì
ps eww $(pgrep -f "headroom proxy") | tr ' ' '\n' | grep -i "api_key\|target\|url"
```

### Lỗi address already in use

Port đang bị chiếm. Kill thủ công:

```bash
lsof -ti :8787 | xargs kill -9
```

Hoặc chạy lại script — script tự dọn dẹp port trước khi start.

### Headroom forward lên api.anthropic.com thay vì backend của bạn

Headroom không nhận được `ANTHROPIC_TARGET_API_URL`. Restart với đúng flag:

```bash
pkill -f "headroom proxy"
ANTHROPIC_TARGET_API_URL="http://localhost:11434" \
ANTHROPIC_API_KEY="your-key" \
headroom proxy --port 8787 \
  --backend anyllm \
  --anyllm-provider openai \
  --anthropic-api-url "http://localhost:11434"
```

### Shell environment override settings.json

Nếu có biến môi trường `ANTHROPIC_BASE_URL` trong shell, nó sẽ thắng `settings.json`:

```bash
# Kiểm tra
echo $ANTHROPIC_BASE_URL

# Tìm nguồn gốc
grep -r "ANTHROPIC" ~/.bashrc ~/.zshrc ~/.zprofile ~/.profile 2>/dev/null

# Unset tạm thời
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY
```

---

## Tham khảo

- [Headroom repo](https://github.com/chopratejas/headroom)
- [Headroom docs](https://headroom-docs.vercel.app/docs)
- [any-llm providers](https://mozilla-ai.github.io/any-llm/providers/)
