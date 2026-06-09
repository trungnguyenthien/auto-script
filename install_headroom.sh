#!/usr/bin/env bash
# ============================================================
# install-headroom.sh
# Cài đặt Headroom proxy + tự động cấu hình Claude Code
# Usage: bash install-headroom.sh
# ============================================================

set -euo pipefail

# ─── màu sắc ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}ℹ️  $*${RESET}"; }
success() { echo -e "${GREEN}✅ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠️  $*${RESET}"; }
error()   { echo -e "${RED}❌ $*${RESET}" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

show_help_content() {
    header "Hướng dẫn cấu hình Headroom & AI Agents"
    
    echo -e "Script này cài đặt Headroom proxy chạy ngầm (local daemon) trên hệ thống"
    echo -e "tại địa chỉ: ${CYAN}http://localhost:<PORT>${RESET} (mặc định: ${CYAN}http://localhost:8787${RESET})."
    echo -e "Dưới đây là hướng dẫn cách cấu hình chi tiết cho các Agent:"
    echo ""
    echo -e "  ${BOLD}1. Cách cập nhật địa chỉ Base URL đi upstream (LLM Backend):${RESET}"
    echo -e "     - Tệp lưu cấu hình của Headroom nằm tại: ${CYAN}~/.config/headroom/.env${RESET}."
    echo -e "     - Hãy sửa trực tiếp tệp này và thay đổi biến ${CYAN}ANTHROPIC_TARGET_API_URL${RESET}."
    echo ""
    echo -e "  ${BOLD}2. Cách cập nhật API Key (Token) đi upstream:${RESET}"
    echo -e "     - Tệp lưu cấu hình của Headroom nằm tại: ${CYAN}~/.config/headroom/.env${RESET}."
    echo -e "     - Hãy sửa trực tiếp tệp này và thay đổi biến ${CYAN}ANTHROPIC_API_KEY${RESET}."
    echo -e "     - ${YELLOW}*Lưu ý:${RESET} Bạn không cần cập nhật API Key thật ở các nơi khác. Headroom sẽ tự động thay thế"
    echo -e "       bằng API Key thật này trước khi gửi đi upstream."
    echo ""
    echo -e "  ${BOLD}3. Hướng dẫn cấu hình cho công cụ AI Agent:${RESET}"
    echo ""
    echo -e "     ${BOLD}A. CLAUDE CODE (.claude/settings.json):${RESET}"
    echo -e "        - Claude Code không tự động đọc model từ Headroom, cần được chỉ định rõ ở thuộc tính \"model\"."
    echo -e "        - ${GREEN}*Bảo mật:${RESET} Bạn có thể để token giả lập (như \"your-api-key\" hoặc \"headroom\") tại đây"
    echo -e "          để tránh lộ API Key thật khi commit dự án lên Git."
    echo -e "${CYAN}----------------.claude/settings.json-----------------------"
    cat << 'EOF'
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
EOF
    echo -e "------------------------------------------------------------${RESET}"
    echo ""
    echo -e "     ${BOLD}B. ZOO CODE (Roo Code / Cline / VS Code Extensions):${RESET}"
    echo -e "        - Mở cài đặt (Settings) trong giao diện của extension và thiết lập:"
    echo -e "          • ${CYAN}API Provider${RESET}: Chọn ${BOLD}Anthropic${RESET} hoặc ${BOLD}OpenAI Compatible${RESET} (tùy LLM Backend)."
    echo -e "          • ${CYAN}Base URL${RESET}: Nhập ${BOLD}http://localhost:8787${RESET}"
    echo -e "          • ${CYAN}API Key${RESET}: Nhập token giả lập (như ${BOLD}headroom${RESET} hoặc ${BOLD}your-api-key${RESET})."
    echo -e "          • ${CYAN}Model ID${RESET}: Nhập tên model thật chạy ở LLM Backend của bạn."
    echo ""
    echo -e "     ${BOLD}C. CONTINUE (Continue.dev):${RESET}"
    echo -e "        - Mở cấu hình tại: ${CYAN}~/.continue/config.yaml${RESET} (hoặc nhấp vào biểu tượng bánh răng)."
    echo -e "        - Thêm cấu hình model dưới đây vào mục ${CYAN}models:${RESET}"
    echo -e "${CYAN}----------------~/.continue/config.yaml---------------------"
    cat << 'EOF'
models:
  - name: "Headroom Claude"
    provider: "anthropic"
    model: "tên-model-của-bạn-ở-backend"
    apiBase: "http://localhost:8787/v1"
    apiKey: "your-api-key"
EOF
    echo -e "------------------------------------------------------------${RESET}"
    echo ""
    echo -e "  ${BOLD}Khởi động lại Headroom sau khi sửa cấu hình .env:${RESET}"
    echo -e "     - Bạn chỉ cần chạy lại script này với flag ${CYAN}--restart${RESET} hoặc ${CYAN}-r${RESET}:"
    echo -e "       ${GREEN}bash install_headroom.sh --restart${RESET}"
    echo ""
}

restart_headroom() {
    info "Đang khởi động lại Headroom proxy..."
    OS_TYPE="$(uname -s)"
    
    # Check if docker container headroom-proxy exists and is running/configured
    if command -v docker &>/dev/null && docker ps -a --format '{{.Names}}' | grep -Eq "^headroom-proxy$"; then
        info "Phát hiện Docker container headroom-proxy, đang khởi động lại..."
        if [[ -f "$HOME/.local/bin/headroom-start" ]]; then
            bash "$HOME/.local/bin/headroom-start"
            success "Khởi động lại Docker container thành công!"
            exit 0
        else
            docker stop headroom-proxy &>/dev/null || true
            docker start headroom-proxy &>/dev/null || true
            success "Khởi động lại Docker container thành công!"
            exit 0
        fi
    fi

    if [[ "$OS_TYPE" == "Darwin" ]]; then
        PLIST_FILE="$HOME/Library/LaunchAgents/ai.headroom.proxy.plist"
        if [[ -f "$PLIST_FILE" ]]; then
            info "Khởi động lại LaunchAgent (macOS)..."
            launchctl unload "$PLIST_FILE" 2>/dev/null || true
            launchctl load "$PLIST_FILE"
            success "Khởi động lại LaunchAgent thành công!"
        else
            error "Không tìm thấy file launchd plist tại: $PLIST_FILE"
        fi
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        SERVICE_FILE="$HOME/.config/systemd/user/headroom-proxy.service"
        if [[ -f "$SERVICE_FILE" ]] || systemctl --user list-unit-files | grep -q "headroom-proxy.service"; then
            info "Khởi động lại systemd service (Linux)..."
            systemctl --user restart headroom-proxy
            success "Khởi động lại systemd service thành công!"
        else
            error "Không tìm thấy systemd service cho headroom-proxy."
        fi
    else
        error "Hệ điều hành không hỗ trợ tự động restart: $OS_TYPE"
    fi
    exit 0
}

uninstall_headroom() {
    info "Bắt đầu gỡ bỏ Headroom proxy..."
    OS_TYPE="$(uname -s)"
    
    # 1. Stop and remove LaunchAgent (macOS)
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        PLIST_FILE="$HOME/Library/LaunchAgents/ai.headroom.proxy.plist"
        if [[ -f "$PLIST_FILE" ]]; then
            info "Đang gỡ bỏ LaunchAgent (macOS)..."
            launchctl unload "$PLIST_FILE" 2>/dev/null || true
            rm -f "$PLIST_FILE"
            success "Đã gỡ bỏ tệp LaunchAgent: $PLIST_FILE"
        fi
    fi
    
    # 2. Stop and remove systemd service (Linux)
    if [[ "$OS_TYPE" == "Linux" ]]; then
        SERVICE_FILE="$HOME/.config/systemd/user/headroom-proxy.service"
        if [[ -f "$SERVICE_FILE" ]] || systemctl --user list-unit-files | grep -q "headroom-proxy.service"; then
            info "Đang gỡ bỏ systemd service (Linux)..."
            systemctl --user stop headroom-proxy.service 2>/dev/null || true
            systemctl --user disable headroom-proxy.service 2>/dev/null || true
            rm -f "$SERVICE_FILE"
            systemctl --user daemon-reload 2>/dev/null || true
            success "Đã gỡ bỏ tệp systemd service"
        fi
    fi
    
    # 3. Stop and remove Docker container if exists
    if command -v docker &>/dev/null; then
        if docker ps -a --format '{{.Names}}' | grep -Eq "^headroom-proxy$"; then
            info "Phát hiện Docker container headroom-proxy, đang dừng và gỡ bỏ..."
            docker stop headroom-proxy &>/dev/null || true
            docker rm headroom-proxy &>/dev/null || true
            success "Đã dừng và xóa Docker container headroom-proxy."
        fi
    fi
    
    # 4. Read port from config .env to kill running process
    local config_port=8787
    local env_file="$HOME/.config/headroom/.env"
    if [[ -f "$env_file" ]]; then
        local env_port=$(grep -E "^HEADROOM_PORT=" "$env_file" | cut -d'=' -f2 || true)
        if [[ -n "$env_port" ]]; then
            config_port="$env_port"
        fi
    fi
    
    # Kill process holding the port
    local pids=$(lsof -ti :"$config_port" 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
        info "Đang tắt các tiến trình đang chiếm dụng port $config_port..."
        echo "$pids" | xargs kill -9 2>/dev/null || true
    fi
    pkill -9 -f "headroom proxy" 2>/dev/null || true
    
    # 5. Remove config and scripts
    info "Đang dọn dẹp các tệp cấu hình và mã nguồn..."
    rm -rf "$HOME/.config/headroom"
    rm -f "$HOME/.local/bin/headroom-start"
    rm -rf "$HOME/.cache/headroom"
    success "Đã dọn dẹp thư mục cấu hình và tệp chạy."
    
    # 6. Uninstall python package
    info "Đang gỡ bỏ gói cài đặt headroom-ai..."
    if command -v pipx &>/dev/null; then
        pipx uninstall headroom-ai &>/dev/null || true
    fi
    if command -v python3 &>/dev/null; then
        python3 -m pip uninstall -y headroom-ai &>/dev/null || true
    fi
    success "Gỡ bỏ hoàn tất! 🎉"
    exit 0
}

show_help() {
    show_help_content
    exit 0
}

show_banner() {
    echo -e "${BOLD}${CYAN}"
    cat << 'EOF'
  _   _                _
 | | | | ___  __ _  __| |_ __ ___   ___  _ __ ___
 | |_| |/ _ \/ _` |/ _` | '__/ _ \ / _ \| '_ ` _ \
 |  _  |  __/ (_| | (_| | | | (_) | (_) | | | | | |
 |_| |_|\___|\__,_|\__,_|_|  \___/ \___/|_| |_| |_|
  + Claude Code Auto-Config
EOF
    echo -e "${RESET}"
    echo -e "  Context compression proxy cho AI agents (60–95% ít tokens hơn)"
    echo -e "  Repo: https://github.com/chopratejas/headroom\n"
}

show_welcome_message() {
    show_banner
    header "Hướng dẫn sử dụng"
    echo -e "Vui lòng chạy script với một trong các flag sau:"
    echo -e "  ${CYAN}--install${RESET}, ${CYAN}-i${RESET}    : Thực hiện cài đặt mới và cấu hình Headroom proxy."
    echo -e "  ${CYAN}--restart${RESET}, ${CYAN}-r${RESET}    : Khởi động lại daemon/container Headroom đang hoạt động."
    echo -e "  ${CYAN}--uninstall${RESET}, ${CYAN}-u${RESET}  : Gỡ bỏ hoàn toàn Headroom proxy và các tệp cấu hình."
    echo -e "  ${CYAN}--help${RESET}, ${CYAN}-h${RESET}       : Xem hướng dẫn cấu hình chi tiết cho các AI Agent (Claude Code, Zoo Code, Continue.dev)."
    echo ""
    echo -e "Ví dụ:"
    echo -e "  ${GREEN}bash install_headroom.sh --install${RESET}"
    echo -e "  ${GREEN}bash install_headroom.sh --restart${RESET}"
    echo -e "  ${GREEN}bash install_headroom.sh --uninstall${RESET}"
    echo -e "  ${GREEN}bash install_headroom.sh --help${RESET}"
    echo ""
}

# Xử lý các flag
if [[ $# -eq 0 ]]; then
    show_welcome_message
    exit 0
fi

# Parsing flags
case "${1}" in
    --help|-h)
        show_help
        ;;
    --restart|-r)
        restart_headroom
        ;;
    --uninstall|-u)
        uninstall_headroom
        ;;
    --install|-i)
        show_banner
        ;;
    *)
        echo -e "${RED}Lỗi: Flag không hợp lệ: ${1}${RESET}" >&2
        show_welcome_message
        exit 1
        ;;
esac

# ─── kiểm tra prerequisites ───────────────────────────────
header "Kiểm tra prerequisites"

MISSING_DOCKER=false

# Docker (optional — chỉ cần nếu chọn mode 3)
if command -v docker &>/dev/null; then
    success "docker đã cài ($(command -v docker))"
else
    warn "docker chưa có — không sao, chỉ cần nếu bạn chọn chế độ Docker"
    MISSING_DOCKER=true
fi

# ─── tìm Python phù hợp (>=3.10), hoặc cài tự động ───────
find_python() {
    # Ưu tiên: python3 → python → python3.x (từ mới đến cũ)
    for cmd in python3 python python3.13 python3.12 python3.11 python3.10; do
        if command -v "$cmd" &>/dev/null; then
            # Kiểm tra version >= 3.10
            if "$cmd" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then
                echo "$cmd"
                return 0
            fi
        fi
    done
    return 1
}

PYTHON_BIN=""
if PYTHON_BIN=$(find_python); then
    PY_VER=$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    success "Python $PY_VER tìm thấy tại: $(command -v "$PYTHON_BIN")"
else
    # Không tìm thấy Python >=3.10 — thử cài tự động
    warn "Không tìm thấy Python 3.10+. Đang cài tự động..."
    OS_TYPE_EARLY="$(uname -s)"

    if [[ "$OS_TYPE_EARLY" == "Darwin" ]]; then
        if command -v brew &>/dev/null; then
            info "Dùng Homebrew để cài python3..."
            brew install python3
        else
            info "Cài Homebrew trước, sau đó cài python3..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew install python3
        fi

    elif [[ "$OS_TYPE_EARLY" == "Linux" ]]; then
        if command -v apt-get &>/dev/null; then
            info "Dùng apt để cài python3..."
            sudo apt-get update -qq
            sudo apt-get install -y python3 python3-pip python3-venv
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y python3 python3-pip
        elif command -v yum &>/dev/null; then
            sudo yum install -y python3 python3-pip
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm python python-pip
        else
            error "Không xác định được package manager. Cài Python 3.10+ thủ công: https://www.python.org/downloads/"
        fi
    else
        error "Không hỗ trợ tự động cài Python trên OS này. Cài thủ công: https://www.python.org/downloads/"
    fi

    # Thử lại sau khi cài
    if PYTHON_BIN=$(find_python); then
        PY_VER=$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        success "Python $PY_VER đã cài thành công"
    else
        # Vẫn không có — kiểm tra xem có python nào không (dù < 3.10)
        for fallback in python3 python; do
            if command -v "$fallback" &>/dev/null; then
                PYTHON_BIN="$fallback"
                PY_VER=$("$fallback" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
                warn "Chỉ tìm thấy Python $PY_VER — headroom yêu cầu 3.10+, có thể gặp lỗi khi cài package."
                warn "Nếu lỗi, hãy nâng cấp Python hoặc chọn chế độ Docker (mode 3)."
                break
            fi
        done

        if [[ -z "$PYTHON_BIN" ]]; then
            error "Không tìm thấy Python. Cài thủ công rồi chạy lại: https://www.python.org/downloads/"
        fi
    fi
fi

# ─── input từ user ────────────────────────────────────────
header "Cấu hình"

echo -e "${BOLD}Nhập CUSTOM_ANTHROPIC_BASE_URL — endpoint backend thực sự của bạn${RESET}"
echo -e "  Ví dụ: https://vertex-key.com/api/v1"
echo -e "         http://localhost:11434"
echo -e "         https://openrouter.ai/api/v1"
echo ""

while true; do
    read -rp "$(echo -e "${CYAN}CUSTOM_ANTHROPIC_BASE_URL${RESET}: ")" CUSTOM_BASE_URL
    CUSTOM_BASE_URL="${CUSTOM_BASE_URL%/}"   # bỏ trailing slash
    if [[ -n "$CUSTOM_BASE_URL" ]]; then
        break
    fi
    warn "Không được để trống."
done

echo ""
read -rp "$(echo -e "${CYAN}ANTHROPIC_AUTH_TOKEN${RESET} (token/api-key cho backend trên, Enter để bỏ qua): ")" USER_AUTH_TOKEN
USER_AUTH_TOKEN="${USER_AUTH_TOKEN:-}"

# Port headroom proxy
HEADROOM_PORT=8787
echo ""
read -rp "$(echo -e "${CYAN}Port cho Headroom proxy${RESET} [${HEADROOM_PORT}]: ")" INPUT_PORT
HEADROOM_PORT="${INPUT_PORT:-$HEADROOM_PORT}"

# Chọn phương thức cài đặt
echo ""
header "Phương thức cài đặt"
echo "  1) pipx — cài isolated (khuyến nghị nếu dùng global)"
echo "  2) pip  — cài headroom-ai vào Python environment hiện tại"
echo "  3) docker — chạy headroom trong container (không cần pip)"
echo ""
read -rp "$(echo -e "${CYAN}Chọn [1/2/3]${RESET} [1]: ")" INSTALL_MODE
INSTALL_MODE="${INSTALL_MODE:-1}"

# ─── cài đặt headroom ─────────────────────────────────────
header "Cài đặt Headroom"

case "$INSTALL_MODE" in
    1)
        if ! command -v pipx &>/dev/null; then
            info "Cài pipx..."
            "$PYTHON_BIN" -m pip install pipx
        fi
        info "Cài headroom-ai[all] via pipx..."
        pipx install --python "$PYTHON_BIN" "headroom-ai[all]" 2>/dev/null || \
            pipx upgrade "headroom-ai[all]"
        HEADROOM_CMD="headroom"
        ;;
    2)
        info "Cài headroom-ai[all] via pip..."
        "$PYTHON_BIN" -m pip install --upgrade "headroom-ai[all]"
        HEADROOM_CMD="headroom"
        ;;
    3)
        if $MISSING_DOCKER; then
            error "Docker chưa cài. Chọn mode 1 hoặc 2, hoặc cài Docker trước."
        fi
        HEADROOM_CMD="docker"
        success "Sẽ dùng Docker image ghcr.io/chopratejas/headroom:latest"
        ;;
    *)
        error "Lựa chọn không hợp lệ."
        ;;
esac

# ─── kill process cũ + clean cache ───────────────────────
header "Dọn dẹp instance cũ"

# Kill bất kỳ process nào đang giữ port
PIDS=$(lsof -ti :"$HEADROOM_PORT" 2>/dev/null || true)
if [[ -n "$PIDS" ]]; then
    warn "Port $HEADROOM_PORT đang bị chiếm bởi PID(s): $PIDS — đang kill..."
    echo "$PIDS" | xargs kill -9 2>/dev/null || true
    sleep 1
    success "Đã kill process cũ"
else
    success "Port $HEADROOM_PORT trống"
fi

# Kill theo tên process phòng trường hợp port đổi
pkill -9 -f "headroom proxy" 2>/dev/null || true

# Xoá cache headroom
HEADROOM_CACHE="${HOME}/.cache/headroom"
if [[ -d "$HEADROOM_CACHE" ]]; then
    info "Xoá cache cũ: $HEADROOM_CACHE"
    rm -rf "$HEADROOM_CACHE"
    success "Đã xoá cache"
fi

# ─── tạo .env file cho headroom ───────────────────────────
header "Tạo cấu hình Headroom"

HEADROOM_CONFIG_DIR="$HOME/.config/headroom"
mkdir -p "$HEADROOM_CONFIG_DIR"

ENV_FILE="$HEADROOM_CONFIG_DIR/.env"
cat > "$ENV_FILE" << EOF
# Headroom proxy environment
# Tạo bởi install-headroom.sh — $(date)

# Backend thực sự mà headroom sẽ forward tới
# (dùng ANTHROPIC_TARGET_API_URL — đúng tên biến headroom nhận)
ANTHROPIC_TARGET_API_URL=${CUSTOM_BASE_URL}

# API key cho upstream backend
ANTHROPIC_API_KEY=${USER_AUTH_TOKEN:-headroom}

# Port headroom lắng nghe
HEADROOM_PORT=${HEADROOM_PORT}
EOF

success "Đã tạo $ENV_FILE"

# ─── tạo start script ─────────────────────────────────────
START_SCRIPT="$HOME/.local/bin/headroom-start"
mkdir -p "$HOME/.local/bin"

if [[ "$INSTALL_MODE" == "3" ]]; then
    # Docker mode
    cat > "$START_SCRIPT" << EOF
#!/usr/bin/env bash
# Khởi động Headroom proxy (Docker mode)
set -euo pipefail

HEADROOM_PORT="${HEADROOM_PORT}"

# ── Kill/remove container cũ ───────────────────────────────
echo "🔪 Dọn dẹp container cũ..."
docker stop headroom-proxy 2>/dev/null || true
docker rm   headroom-proxy 2>/dev/null || true

echo "🚀 Khởi động Headroom proxy (Docker) trên port \$HEADROOM_PORT..."
echo "   → Forward tới: ${CUSTOM_BASE_URL}"

docker run -d \\
    --name headroom-proxy \\
    --restart unless-stopped \\
    -p "\${HEADROOM_PORT}:8787" \\
    -e "ANTHROPIC_TARGET_API_URL=${CUSTOM_BASE_URL}" \\
    -e "ANTHROPIC_API_KEY=${USER_AUTH_TOKEN:-headroom}" \\
    ghcr.io/chopratejas/headroom:latest \\
    proxy --port 8787 \\
    --backend anyllm \\
    --anyllm-provider openai \\
    --anthropic-api-url "${CUSTOM_BASE_URL}"

echo "✅ Headroom đang chạy tại http://localhost:\${HEADROOM_PORT}"
echo "   Dùng 'docker logs -f headroom-proxy' để xem logs"
EOF
else
    # pip/pipx mode
    cat > "$START_SCRIPT" << EOF
#!/usr/bin/env bash
# Khởi động Headroom proxy (pip/pipx mode)
set -euo pipefail

HEADROOM_PORT="${HEADROOM_PORT}"

# ── Kill process cũ đang giữ port ──────────────────────────
echo "🔪 Dọn dẹp process cũ trên port \$HEADROOM_PORT..."
PIDS=\$(lsof -ti :\$HEADROOM_PORT 2>/dev/null || true)
if [[ -n "\$PIDS" ]]; then
    echo "   Kill PIDs: \$PIDS"
    echo "\$PIDS" | xargs kill -9 2>/dev/null || true
    sleep 1
fi

# ── Xoá cache headroom ──────────────────────────────────────
CACHE_DIR="\${HOME}/.cache/headroom"
if [[ -d "\$CACHE_DIR" ]]; then
    echo "🗑️  Xoá cache: \$CACHE_DIR"
    rm -rf "\$CACHE_DIR"
fi

# ── Set env ────────────────────────────────────────────────
export ANTHROPIC_TARGET_API_URL="${CUSTOM_BASE_URL}"
export ANTHROPIC_API_KEY="${USER_AUTH_TOKEN:-headroom}"
export HEADROOM_TELEMETRY=off

echo "🚀 Khởi động Headroom proxy trên port \$HEADROOM_PORT..."
echo "   → Forward tới: ${CUSTOM_BASE_URL}"

exec headroom proxy \\
    --port "\$HEADROOM_PORT" \\
    --backend anyllm \\
    --anyllm-provider openai \\
    --anthropic-api-url "${CUSTOM_BASE_URL}" \\
    --no-telemetry
EOF
fi

chmod +x "$START_SCRIPT"
success "Đã tạo start script: $START_SCRIPT"

# ─── tạo launchd plist (macOS) hoặc systemd service (Linux) ──
OS_TYPE="$(uname -s)"

if [[ "$OS_TYPE" == "Darwin" ]] && [[ "$INSTALL_MODE" != "3" ]]; then
    header "Tạo launchd service (macOS)"

    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$PLIST_DIR/ai.headroom.proxy.plist"
    mkdir -p "$PLIST_DIR"

    HEADROOM_BIN="$(command -v headroom 2>/dev/null || echo "$HOME/.local/bin/headroom")"

    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.headroom.proxy</string>
    <key>ProgramArguments</key>
    <array>
        <string>${HEADROOM_BIN}</string>
        <string>proxy</string>
        <string>--port</string>
        <string>${HEADROOM_PORT}</string>
        <string>--backend</string>
        <string>anyllm</string>
        <string>--anyllm-provider</string>
        <string>openai</string>
        <string>--anthropic-api-url</string>
        <string>${CUSTOM_BASE_URL}</string>
        <string>--no-telemetry</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>ANTHROPIC_TARGET_API_URL</key>
        <string>${CUSTOM_BASE_URL}</string>
        <key>ANTHROPIC_API_KEY</key>
        <string>${USER_AUTH_TOKEN:-headroom}</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.config/headroom/proxy.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.config/headroom/proxy-error.log</string>
</dict>
</plist>
EOF

    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"
    success "Đã đăng ký launchd service — Headroom tự khởi động cùng macOS"

elif [[ "$OS_TYPE" == "Linux" ]] && [[ "$INSTALL_MODE" != "3" ]]; then
    header "Tạo systemd user service (Linux)"

    SYSTEMD_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_DIR"
    SERVICE_FILE="$SYSTEMD_DIR/headroom-proxy.service"

    HEADROOM_BIN="$(command -v headroom 2>/dev/null || echo "$HOME/.local/bin/headroom")"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Headroom Context Compression Proxy
After=network.target

[Service]
ExecStart=${HEADROOM_BIN} proxy \
    --port ${HEADROOM_PORT} \
    --backend anyllm \
    --anyllm-provider openai \
    --anthropic-api-url ${CUSTOM_BASE_URL} \
    --no-telemetry
Environment="ANTHROPIC_TARGET_API_URL=${CUSTOM_BASE_URL}"
Environment="ANTHROPIC_API_KEY=${USER_AUTH_TOKEN:-headroom}"
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now headroom-proxy.service
    success "Đã kích hoạt systemd service: headroom-proxy"
fi



# ─── tóm tắt kiến trúc ────────────────────────────────────
header "Kiến trúc sau khi cài"

echo -e "
  ${BOLD}Claude Code${RESET}
       │  ANTHROPIC_BASE_URL=http://localhost:${HEADROOM_PORT}
       ▼
  ${CYAN}┌─────────────────────────────────────────────┐${RESET}
  ${CYAN}│  Headroom Proxy  (localhost:${HEADROOM_PORT})           │${RESET}
  ${CYAN}│  • Nén tool outputs, logs, RAG (60–95%)    │${RESET}
  ${CYAN}│  • CacheAligner cho KV cache hits          │${RESET}
  ${CYAN}│  • CCR reversible compression              │${RESET}
  ${CYAN}└─────────────────────────────────────────────┘${RESET}
       │  forward tới
       ▼
  ${BOLD}${CUSTOM_BASE_URL}${RESET}
"

# ─── quick test ───────────────────────────────────────────
if [[ "$INSTALL_MODE" != "3" ]]; then
    header "Khởi động test"
    info "Thử khởi động headroom proxy..."

    if ANTHROPIC_TARGET_API_URL="$CUSTOM_BASE_URL" \
       ANTHROPIC_API_KEY="${USER_AUTH_TOKEN:-headroom}" \
       headroom proxy --port "$HEADROOM_PORT" \
         --backend anyllm \
         --anyllm-provider openai \
         --anthropic-api-url "$CUSTOM_BASE_URL" \
         --no-telemetry &
    PROXY_PID=$!
    sleep 2
    then
        if kill -0 $PROXY_PID 2>/dev/null; then
            success "Headroom proxy đang chạy (PID $PROXY_PID)"
            kill $PROXY_PID 2>/dev/null || true
            info "Đã dừng test instance. Service sẽ được quản lý bởi launchd/systemd."
        fi
    fi
fi

# ─── done ─────────────────────────────────────────────────
header "Hoàn thành 🎉"

echo -e "  ${BOLD}Các file đã tạo:${RESET}"
echo -e "  • ${CYAN}$ENV_FILE${RESET}"
echo -e "  • ${CYAN}$START_SCRIPT${RESET}"
echo ""
echo -e "  ${BOLD}Thủ công start/stop:${RESET}"
if [[ "$OS_TYPE" == "Darwin" ]]; then
    echo -e "  • Start:   ${CYAN}launchctl load ~/Library/LaunchAgents/ai.headroom.proxy.plist${RESET}"
    echo -e "  • Stop:    ${CYAN}launchctl unload ~/Library/LaunchAgents/ai.headroom.proxy.plist${RESET}"
    echo -e "  • Logs:    ${CYAN}tail -f ~/.config/headroom/proxy.log${RESET}"
elif [[ "$OS_TYPE" == "Linux" ]]; then
    echo -e "  • Start:   ${CYAN}systemctl --user start headroom-proxy${RESET}"
    echo -e "  • Stop:    ${CYAN}systemctl --user stop headroom-proxy${RESET}"
    echo -e "  • Logs:    ${CYAN}journalctl --user -u headroom-proxy -f${RESET}"
fi
if [[ "$INSTALL_MODE" == "3" ]]; then
    echo -e "  • Start:   ${CYAN}bash $START_SCRIPT${RESET}"
    echo -e "  • Logs:    ${CYAN}docker logs -f headroom-proxy${RESET}"
    echo -e "  • Stop:    ${CYAN}docker stop headroom-proxy && docker rm headroom-proxy${RESET}"
fi
echo ""
echo -e "  ${BOLD}Kiểm tra savings:${RESET}"
echo -e "  • ${CYAN}headroom stats${RESET}"
echo ""
echo -e "  ${BOLD}Docs:${RESET} https://headroom-docs.vercel.app/docs"
echo ""

# In hướng dẫn cấu hình AI Agent sau khi cài đặt thành công
show_help_content