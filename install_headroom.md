# install-headroom.sh

Script tự động cài đặt [Headroom](https://github.com/chopratejas/headroom) — một context compression proxy giúp nén context cho AI Agents (như Claude Code và các agent khác) chạy ngầm (daemon) cục bộ.

---

## Headroom là gì?

Headroom là một proxy đứng giữa AI Agent và LLM backend, tự động nén context trước khi gửi request. Kết quả là ít token hơn 60–95% mà output không thay đổi, giúp giảm chi phí và tăng tốc độ phản hồi đáng kể khi làm việc với các tác vụ có context lớn như code review, tool calls, hay RAG.

```
AI Agent (e.g. Claude Code)
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
curl -O https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_headroom.sh
```

### Bước 2 — Chạy script

Để thực hiện cài đặt mới và tự động cấu hình Headroom proxy, hãy chạy script bằng cờ `--install` (hoặc `-i`):

```bash
bash install_headroom.sh --install
```

Để xem danh sách các flag được hỗ trợ, bạn có thể chạy script trực tiếp không kèm flag hoặc xem hướng dẫn cấu hình chi tiết cho các Agent thông qua cờ `--help` (hoặc `-h`):

```bash
bash install_headroom.sh --help
```

### Gỡ bỏ (Uninstall) hoàn toàn

Để dừng các service đang chạy ngầm (hoặc Docker container) và xóa sạch các tệp tin cấu hình của Headroom khỏi hệ thống, hãy chạy script với cờ `--uninstall` (hoặc `-u`):

```bash
bash install_headroom.sh --uninstall
```

### Bước 3 — Trả lời các câu hỏi

Script hỏi lần lượt 4 thông tin:

```
CUSTOM_ANTHROPIC_BASE_URL : http://localhost:11434
ANTHROPIC_AUTH_TOKEN      : your-api-key-here
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

### Port _(mặc định: 8787)_

Port Headroom proxy lắng nghe trên máy local. Chỉ thay đổi nếu port này đã bị chiếm bởi service khác.

### Chế độ cài đặt

| Chế độ     | Mô tả                                             | Khi nào dùng            |
| ---------- | ------------------------------------------------- | ----------------------- |
| `1` pipx   | Cài isolated, không ảnh hưởng Python global       | Khuyến nghị cho máy dev |
| `2` pip    | Cài `headroom-ai` vào Python environment hiện tại | Nhanh, đơn giản         |
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

### 6. Quick test

Khởi động Headroom một lần để xác nhận không có lỗi, sau đó dừng lại — service thực sự được quản lý bởi launchd/systemd.

---

## Các file được tạo ra

```
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

### Khởi động lại (Restart) nhanh

Sau khi bạn thay đổi cấu hình trong tệp `.env`, thay vì chạy các lệnh thủ công ở trên, bạn chỉ cần chạy lại script này với cờ `--restart` (hoặc `-r`):

```bash
bash install_headroom.sh --restart
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

## Hướng dẫn cấu hình cho công cụ AI Agent

### A. Claude Code (.claude/settings.json)

Claude Code không tự động đọc model từ Headroom, cần được chỉ định rõ ở thuộc tính `"model"`. Bạn có thể lưu cấu hình này trực tiếp vào tệp `.claude/settings.json` trong thư mục dự án của bạn:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:8787",
    "ANTHROPIC_AUTH_TOKEN": "your-api-key",
    "ANTHROPIC_API_KEY": "your-api-key",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_INTERLEAVED_THINKING": "1"
  },
  "model": "tên-model-của-bạn-ở-backend"
}
```

> [!TIP]
> **Bảo mật:** Bạn có thể để token giả lập (như `"your-api-key"` hoặc `"headroom"`) tại đây để tránh lộ API Key thật khi commit dự án lên Git. Headroom sẽ tự động nạp API Key thật từ file cấu hình chung trước khi gửi request đi upstream.

### B. Zoo Code (Roo Code / Cline)

Nếu sử dụng extension **Zoo Code** hoặc **Roo Code** / **Cline** trên VS Code, bạn cấu hình trực tiếp qua giao diện Settings của extension:
- **API Provider**: Chọn `Anthropic` hoặc `OpenAI Compatible` (tùy thuộc LLM Backend).
- **Base URL**: Nhập `http://localhost:8787` (hoặc port proxy của bạn).
- **API Key**: Nhập token giả lập (như `headroom` hoặc `your-api-key`).
- **Model ID**: Nhập tên model thực tế đang chạy ở backend của bạn.

### C. Continue (Continue.dev)

Nếu sử dụng extension **Continue** trên VS Code hoặc JetBrains, bạn cấu hình thông qua tệp `~/.continue/config.yaml` (hoặc nhấp vào biểu tượng bánh răng ở góc dưới thanh sidebar của Continue) và bổ sung model mới vào mục `models`:

```yaml
models:
  - name: "Headroom Claude"
    provider: "anthropic"
    model: "tên-model-của-bạn-ở-backend"
    apiBase: "http://localhost:8787/v1"
    apiKey: "your-api-key"
```

---

## Tham khảo

- [Headroom repo](https://github.com/chopratejas/headroom)
- [Headroom docs](https://headroom-docs.vercel.app/docs)
- [any-llm providers](https://mozilla-ai.github.io/any-llm/providers/)
